//
//  OTPAuthAppDelegate.m
//
//  Copyright 2011 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License.  You may obtain a copy
//  of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
//  License for the specific language governing permissions and limitations under
//  the License.
//



#import "OTPAuthAppDelegate.h"
#import "GTMDefines.h"
#import "OTPAuthURL.h"
#import "HOTPGenerator.h"
#import "TOTPGenerator.h"
#import "OTPTableViewCell.h"
#import "OTPAuthAboutController.h"
#import "OTPWelcomeViewController.h"
#import "OTPAuthBarClock.h"
#import "UIColor+MobileColors.h"
#import "GTMLocalizedString.h"
#import <DropboxSDK/DropboxSDK.h>
#import "OTPAccount.h"


static NSString *const kOTPKeychainEntriesArray = @"OTPKeychainEntries";

@interface OTPGoodTokenSheet : UIActionSheet
@property(readwrite, nonatomic, retain) OTPAuthURL *authURL;
@end

@interface OTPAuthAppDelegate () <DBSessionDelegate, TICDSApplicationSyncManagerDelegate, TICDSDocumentSyncManagerDelegate>
// The OTPAuthURL objects in this array are loaded from the keychain at
// startup and serialized there on shutdown.
@property (nonatomic, retain) NSMutableArray *authURLs;
@property (nonatomic, assign) RootViewController *rootViewController;
@property (nonatomic, assign) UIBarButtonItem *editButton;
@property (nonatomic, assign) OTPEditingState editingState;
@property (nonatomic, retain) OTPAuthURL *urlBeingAdded;
@property (nonatomic, retain) UIAlertView *urlAddAlert;

- (void)updateUI;
- (void)updateEditing:(UITableView *)tableview;
@end

@implementation OTPAuthAppDelegate
@synthesize window = window_;
@synthesize authURLEntryController = authURLEntryController_;
@synthesize navigationController = navigationController_;
@synthesize authURLs = authURLs_;
@synthesize rootViewController = rootViewController_;
@synthesize editButton = editButton_;
@synthesize editingState = editingState_;
@synthesize urlAddAlert = urlAddAlert_;
@synthesize authURLEntryNavigationItem = authURLEntryNavigationItem_;
@synthesize legalButton = legalButton_;
@synthesize settingsButton = settingsButton_;
@synthesize navigationItem = navigationItem_;
@synthesize urlBeingAdded = urlBeingAdded_;
@synthesize managedObjectContext=__managedObjectContext;
@synthesize managedObjectModel=__managedObjectModel;
@synthesize persistentStoreCoordinator=__persistentStoreCoordinator;

- (void)dealloc {
  self.window = nil;
  self.authURLEntryController = nil;
  self.navigationController = nil;
  self.rootViewController = nil;
  self.authURLs = nil;
  self.editButton = nil;
  self.urlBeingAdded = nil;
  self.legalButton = nil;
  self.settingsButton = nil;
  self.navigationItem = nil;
  self.urlAddAlert = nil;
  self.authURLEntryNavigationItem = nil;

  [__managedObjectContext release];
  [__managedObjectModel release];
  [__persistentStoreCoordinator release];
  [__managedObjectContext release];
  [super dealloc];
}

#pragma mark Apple Stuff
- (void)applicationWillTerminate:(UIApplication *)application
{
  // Saves changes in the application's managed object context before the application terminates.
  [self saveContext];
}

- (void)awakeFromNib {
  self.legalButton.title
    = GTMLocalizedString(@"Legal",
                         @"Legal Information Button Title");
  self.settingsButton.title
    = GTMLocalizedString(@"⚙",
                       @"Settings Button Title");
  self.navigationItem.title
    = GTMLocalizedString(@"Better Authenticator",
                         @"Product Name");
  self.authURLEntryNavigationItem.title
    = GTMLocalizedString(@"Add Token",
                         @"Add Token Navigation Screen Title");
  
  RootViewController *rootViewController = (RootViewController *)[self.navigationController topViewController];   
  rootViewController.managedObjectContext = self.managedObjectContext; 
}

- (void)saveContext
{
  NSError *error = nil;
  NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
  if (managedObjectContext != nil)
  {
    if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error])
    {
      /*
       Replace this implementation with code to handle the error appropriately.
       
       abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
       */
      NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
      abort();
    }
  }
}

- (void)updateEditing:(UITableView *)tableView {
  if ([self.authURLs count] == 0 && [tableView isEditing]) {
    [tableView setEditing:NO animated:YES];
  }
}

- (void)updateUI {
  BOOL hidden = YES;
  for (OTPAuthURL *url in self.authURLs) {
    if ([url isMemberOfClass:[TOTPAuthURL class]]) {
      hidden = NO;
      break;
    }
  }
  self.rootViewController.clock.hidden = hidden;
  self.editButton.enabled = [self.authURLs count] > 0;
}


#pragma mark -
#pragma mark Application Delegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activityDidIncrease:) name:TICDSApplicationSyncManagerDidIncreaseActivityNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activityDidDecrease:) name:TICDSApplicationSyncManagerDidDecreaseActivityNotification object:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activityDidIncrease:) name:TICDSDocumentSyncManagerDidIncreaseActivityNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activityDidDecrease:) name:TICDSDocumentSyncManagerDidDecreaseActivityNotification object:nil];
  
  
  self.rootViewController = (RootViewController*)[self.navigationController topViewController];
  [self.window addSubview:self.navigationController.view];
  
  [self.window makeKeyAndVisible];
  
  DBSession* dbSession = [[[DBSession alloc] initWithAppKey:@"8wepacxs7pwbjvc" appSecret:@"ls8797auelpazd5" root:kDBRootAppFolder] autorelease];
  dbSession.delegate = self;
  [DBSession setSharedSession:dbSession];
  [dbSession release];
  
  if ([[DBSession sharedSession] isLinked]) {
    [self registerSyncManager];
  } else {
    [[DBSession sharedSession] linkFromController:self.navigationController];
  }
  
  return YES;
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
  OTPAuthURL *authURL = [OTPAuthURL authURLWithURL:url secret:nil];
  if (authURL) {
    NSString *title = GTMLocalizedString(@"Add Token",
                                         @"Add Token Alert Title");
    NSString *message
      = [NSString stringWithFormat:
         GTMLocalizedString(@"Do you want to add the token named “%@”?",
                            @"Add Token Message"), [authURL name]];
    NSString *noButton = GTMLocalizedString(@"No", @"No");
    NSString *yesButton = GTMLocalizedString(@"Yes", @"Yes");

    self.urlAddAlert = [[[UIAlertView alloc] initWithTitle:title
                                                   message:message
                                                  delegate:self
                                         cancelButtonTitle:noButton
                                         otherButtonTitles:yesButton, nil]
                        autorelease];
    self.urlBeingAdded = authURL;
    [self.urlAddAlert show];
  }
  
  
  if ([[DBSession sharedSession] handleOpenURL:url]) {
    if ([[DBSession sharedSession] isLinked]) {
      NSLog(@"App linked successfully!");
      [self registerSyncManager];
    }
    
    return YES;
  }
  
  return authURL != nil;
}

#pragma mark -
#pragma mark OTPManualAuthURLEntryControllerDelegate

- (void)authURLEntryController:(OTPAuthURLEntryController*)controller
              didCreateAuthURL:(OTPAuthURL *)authURL {
  [self.navigationController dismissViewControllerAnimated:YES completion:nil];
  [self.navigationController popToRootViewControllerAnimated:NO];
  [self updateUI];
  UITableView *tableView = (UITableView*)self.rootViewController.view;
  [tableView reloadData];
}

#pragma mark -
#pragma mark UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
  [self.rootViewController setEditing:NO animated:animated];
  // Only display the toolbar for the rootViewController.
  BOOL hidden = viewController != self.rootViewController;
  [navigationController setToolbarHidden:hidden animated:YES];
}

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated {
  if ([viewController isMemberOfClass:[RootViewController class]]) {
    self.editButton = viewController.editButtonItem;
    UIToolbar *toolbar = self.navigationController.toolbar;
    NSMutableArray *items = [NSMutableArray arrayWithArray:toolbar.items];
    // We are replacing our "proxy edit button" with a real one.
    //[items replaceObjectAtIndex:0 withObject:self.editButton];
    //toolbar.items = items;

    [self updateUI];
  }
}

#pragma mark -
#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  NSString *cellIdentifier = nil;
  Class cellClass = Nil;

  // See otp_tableViewWillBeginEditing for comments on why this is being done.
  NSUInteger idx = self.editingState == kOTPEditingTable ? [indexPath row] : [indexPath section];
  OTPAuthURL *url = [self.authURLs objectAtIndex:idx];
  if ([url isMemberOfClass:[HOTPAuthURL class]]) {
    cellIdentifier = @"HOTPCell";
    cellClass = [HOTPTableViewCell class];
  } else if ([url isMemberOfClass:[TOTPAuthURL class]]) {
    cellIdentifier = @"TOTPCell";
    cellClass = [TOTPTableViewCell class];
  }
  UITableViewCell *cell
    = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
  if (!cell) {
    cell = [[[cellClass alloc] initWithStyle:UITableViewCellStyleDefault
                             reuseIdentifier:cellIdentifier] autorelease];
  }
  [(OTPTableViewCell *)cell setAuthURL:url];
  return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  // See otp_tableViewWillBeginEditing for comments on why this is being done.
  return self.editingState == kOTPEditingTable ? 1 : [self.authURLs count];
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {
  // See otp_tableViewWillBeginEditing for comments on why this is being done.
  return self.editingState == kOTPEditingTable ? [self.authURLs count] : 1;
}

- (void)tableView:(UITableView *)tableView
    moveRowAtIndexPath:(NSIndexPath *)fromIndexPath
           toIndexPath:(NSIndexPath *)toIndexPath {
  NSUInteger oldIndex = [fromIndexPath row];
  NSUInteger newIndex = [toIndexPath row];
  [self.authURLs exchangeObjectAtIndex:oldIndex withObjectAtIndex:newIndex];
}

- (void)tableView:(UITableView *)tableView
   commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    OTPTableViewCell *cell
      = (OTPTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    [cell didEndEditing];
    [tableView beginUpdates];
    NSUInteger idx = self.editingState == kOTPEditingTable ? [indexPath row] : [indexPath section];
    OTPAuthURL *authURL = [self.authURLs objectAtIndex:idx];

    // See otp_tableViewWillBeginEditing for comments on why this is being done.
    if (self.editingState == kOTPEditingTable) {
      NSIndexPath *path = [NSIndexPath indexPathForRow:idx inSection:0];
      NSArray *rows = [NSArray arrayWithObject:path];
      [tableView deleteRowsAtIndexPaths:rows
                       withRowAnimation:UITableViewRowAnimationFade];
    } else {
      NSIndexSet *set = [NSIndexSet indexSetWithIndex:idx];
      [tableView deleteSections:set
               withRowAnimation:UITableViewRowAnimationFade];
    }
    
    [self.authURLs removeObjectAtIndex:idx];
    [tableView endUpdates];
    [self updateUI];
    if ([self.authURLs count] == 0 && self.editingState != kOTPEditingSingleRow) {
      [self.editButton.target performSelector:self.editButton.action withObject:self];
    }
  }
}

#pragma mark -
#pragma mark UITableViewDelegate

- (void)tableView:(UITableView*)tableView
    willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath {
  _GTMDevAssert(self.editingState == kOTPNotEditing, @"Should not be editing");
  OTPTableViewCell *cell
      = (OTPTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
  [cell willBeginEditing];
  self.editingState = kOTPEditingSingleRow;
}

- (void)tableView:(UITableView*)tableView
   didEndEditingRowAtIndexPath:(NSIndexPath *)indexPath {
  _GTMDevAssert(self.editingState == kOTPEditingSingleRow, @"Must be editing single row");
  OTPTableViewCell *cell
      = (OTPTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
  [cell didEndEditing];
  self.editingState = kOTPNotEditing;
}

#pragma mark -
#pragma mark OTPTableViewDelegate

// With iOS <= 4 there doesn't appear to be a way to move rows around safely
// in a multisectional table where you want to maintain a single row per
// section. You have control over where a row would go into a section with
// tableView:targetIndexPathForMoveFromRowAtIndexPath:toProposedIndexPath:
// but it doesn't allow you to enforce only one row per section.
// By doing this we collapse the table into a single section with multiple rows
// when editing, and then expand back to the "spaced" out view when editing is
// done. We only want this to be done when editing the entire table (by hitting
// the edit button) as when you swipe a row to edit it doesn't allow you
// to move the row.
// When a row is swiped, tableView:willBeginEditingRowAtIndexPath: is called
// first, which means that self.editingState will be set to kOTPEditingSingleRow
// This means that in all code that deals with indexes of items that we need
// to check to see if self.editingState == kOTPEditingTable to know whether to
// check for the index of rows in section 0, or the indexes of the sections
// themselves.
- (void)otp_tableViewWillBeginEditing:(UITableView *)tableView {
  if (self.editingState == kOTPNotEditing) {
    self.editingState = kOTPEditingTable;
    [tableView reloadData];
  }
}

- (void)otp_tableViewDidEndEditing:(UITableView *)tableView {
  if (self.editingState == kOTPEditingTable) {
    self.editingState = kOTPNotEditing;
    [tableView reloadData];
  }
}

#pragma mark -
#pragma mark UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView
    clickedButtonAtIndex:(NSInteger)buttonIndex {
  _GTMDevAssert(alertView == self.urlAddAlert, @"Unexpected Alert");
  if (buttonIndex == 1) {
    [self authURLEntryController:nil
                didCreateAuthURL:self.urlBeingAdded];
  }
  self.urlBeingAdded = nil;
  self.urlAddAlert = nil;
}

#pragma mark -
#pragma mark Actions

-(IBAction)addAuthURL:(id)sender {
  [self.navigationController popToRootViewControllerAnimated:NO];
  [self.rootViewController setEditing:NO animated:NO];
  [self.navigationController presentViewController:self.authURLEntryController
                                          animated:YES completion: nil];
}

- (IBAction)showLegalInformation:(id)sender {
  OTPAuthAboutController *controller
      = [[[OTPAuthAboutController alloc] init] autorelease];
  [self.navigationController pushViewController:controller animated:YES];
}

- (IBAction)showSettings:(id)sender {
  OTPAuthAboutController *controller
  = [[[OTPAuthAboutController alloc] init] autorelease];
  [self.navigationController pushViewController:controller animated:YES];
}

- (IBAction)beginSync:(id)sender {
  // Save the managed object context to cause sync change objects to be written
  NSError *saveError = nil;
  [self.managedObjectContext save:&saveError];
  if (saveError != nil) {
    NSLog(@"%s %@", __PRETTY_FUNCTION__, saveError);
  }
  
  [self.documentSyncManager initiateSynchronization];
}

- (void)registerSyncManager
{
  TICDSDropboxSDKBasedApplicationSyncManager *manager = [TICDSDropboxSDKBasedApplicationSyncManager defaultApplicationSyncManager];
  
  NSString *clientUuid = [[NSUserDefaults standardUserDefaults] stringForKey:@"iOSNotebookAppSyncClientUUID"];
  if (clientUuid == nil) {
    clientUuid = [TICDSUtilities uuidString];
    [[NSUserDefaults standardUserDefaults] setValue:clientUuid forKey:@"iOSNotebookAppSyncClientUUID"];
  }
  
  NSString *deviceDescription = [[UIDevice currentDevice] name];
  
  [manager registerWithDelegate:self
            globalAppIdentifier:@"info.hasno.app.BetterAuthenticator"
         uniqueClientIdentifier:clientUuid
                    description:deviceDescription
                       userInfo:nil];
}

#pragma mark - TICDSApplicationSyncManagerDelegate methods

- (void)applicationSyncManagerDidPauseRegistrationToAskWhetherToUseEncryptionForFirstTimeRegistration:(TICDSApplicationSyncManager *)aSyncManager
{
  [aSyncManager continueRegisteringWithEncryptionPassword:@"password"];
}

- (void)applicationSyncManagerDidPauseRegistrationToRequestPasswordForEncryptedApplicationSyncData:(TICDSApplicationSyncManager *)aSyncManager
{
  [aSyncManager continueRegisteringWithEncryptionPassword:@"password"];
}

- (TICDSDocumentSyncManager *)applicationSyncManager:(TICDSApplicationSyncManager *)aSyncManager preConfiguredDocumentSyncManagerForDownloadedDocumentWithIdentifier:(NSString *)anIdentifier atURL:(NSURL *)aFileURL
{
  return nil;
}

- (void)applicationSyncManagerDidFinishRegistering:(TICDSApplicationSyncManager *)aSyncManager
{
  self.managedObjectContext.synchronized = YES;
  
  TICDSDropboxSDKBasedDocumentSyncManager *docSyncManager = [[TICDSDropboxSDKBasedDocumentSyncManager alloc] init];
  
  [docSyncManager registerWithDelegate:self
                        appSyncManager:aSyncManager
                  managedObjectContext:[self managedObjectContext]
                    documentIdentifier:@"OTPAccount"
                           description:@"OTP account data"
                              userInfo:nil];
  
  [self setDocumentSyncManager:docSyncManager];
  [docSyncManager release];
}

#pragma mark - TICDSDocumentSyncManagerDelegate methods

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didPauseSynchronizationAwaitingResolutionOfSyncConflict:(id)aConflict
{
  [aSyncManager continueSynchronizationByResolvingConflictWithResolutionType:TICDSSyncConflictResolutionTypeLocalWins];
}

- (NSURL *)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager URLForWholeStoreToUploadForDocumentWithIdentifier:(NSString *)anIdentifier description:(NSString *)aDescription userInfo:(NSDictionary *)userInfo
{
  return [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"OTPAccounts.sqlite"];
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didPauseRegistrationAsRemoteFileStructureDoesNotExistForDocumentWithIdentifier:(NSString *)anIdentifier description:(NSString *)aDescription userInfo:(NSDictionary *)userInfo
{
  self.downloadStoreAfterRegistering = NO;
  [aSyncManager continueRegistrationByCreatingRemoteFileStructure:YES];
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didPauseRegistrationAsRemoteFileStructureWasDeletedForDocumentWithIdentifier:(NSString *)anIdentifier description:(NSString *)aDescription userInfo:(NSDictionary *)userInfo
{
  self.downloadStoreAfterRegistering = NO;
  [aSyncManager continueRegistrationByCreatingRemoteFileStructure:YES];
}

- (void)documentSyncManagerDidFinishRegistering:(TICDSDocumentSyncManager *)aSyncManager
{
  if (self.shouldDownloadStoreAfterRegistering) {
    [aSyncManager initiateDownloadOfWholeStore];
  } else {
    [aSyncManager initiateSynchronization];
  }
  
  [aSyncManager beginPollingRemoteStorageForChanges];
}

- (void)documentSyncManagerDidDetermineThatClientHadPreviouslyBeenDeletedFromSynchronizingWithDocument:(TICDSDocumentSyncManager *)aSyncManager
{
  self.downloadStoreAfterRegistering = YES;
}

- (BOOL)documentSyncManagerShouldUploadWholeStoreAfterDocumentRegistration:(TICDSDocumentSyncManager *)aSyncManager
{
  return self.shouldDownloadStoreAfterRegistering == NO;
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager willReplaceStoreWithDownloadedStoreAtURL:(NSURL *)aStoreURL
{
  NSError *anyError = nil;
  BOOL success = [self.persistentStoreCoordinator removePersistentStore:[self.persistentStoreCoordinator persistentStoreForURL:aStoreURL] error:&anyError];
  
  if (success == NO) {
    NSLog(@"Failed to remove persistent store at %@: %@", aStoreURL, anyError);
  }
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didReplaceStoreWithDownloadedStoreAtURL:(NSURL *)aStoreURL
{
  NSError *anyError = nil;
  id store = [self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:aStoreURL options:nil error:&anyError];
  
  if (store == nil) {
    NSLog(@"Failed to add persistent store at %@: %@", aStoreURL, anyError);
  }
}

- (BOOL)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager shouldBeginSynchronizingAfterManagedObjectContextDidSave:(NSManagedObjectContext *)aMoc;
{
  return YES;
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didMakeChangesToObjectsInBackgroundContextAndSaveWithNotification:(NSNotification *)aNotification
{
  NSError *saveError = nil;
  [self.managedObjectContext save:&saveError];
  if (saveError != nil) {
    NSLog(@"%s %@", __PRETTY_FUNCTION__, saveError);
  }
}

- (void)documentSyncManager:(TICDSDocumentSyncManager *)aSyncManager didFailToSynchronizeWithError:(NSError *)anError
{
  NSLog(@"%s %@", __PRETTY_FUNCTION__, anError);
}

#pragma mark - DBSessionDelegate methods

- (void)sessionDidReceiveAuthorizationFailure:(DBSession *)session userId:(NSString *)userId
{
  [[DBSession sharedSession] linkFromController:self.navigationController];
}

#pragma mark - Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext
{
  if (__managedObjectContext != nil)
  {
    return __managedObjectContext;
  }
  
  NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
  if (coordinator != nil)
  {
    __managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [__managedObjectContext setPersistentStoreCoordinator:coordinator];
  }
  return __managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel
{
  if (__managedObjectModel != nil)
  {
    return __managedObjectModel;
  }
  NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"OTPAuthModel" withExtension:@"momd"];
  __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
  
  NSLog(@"%@", __managedObjectModel);
  return __managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
  if (__persistentStoreCoordinator != nil)
  {
    return __persistentStoreCoordinator;
  }
  
  NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"OTPAccounts.sqlite"];
  
  /* Add the check for an existing store here... */
  if ([[NSFileManager defaultManager] fileExistsAtPath:storeURL.path] == NO) {
    self.downloadStoreAfterRegistering = YES;
  }
  
  NSError *error = nil;
  __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
  if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error])
  {
    /*
     Replace this implementation with code to handle the error appropriately.
     
     abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
     
     Typical reasons for an error here include:
     * The persistent store is not accessible;
     * The schema for the persistent store is incompatible with current managed object model.
     Check the error message to determine what the actual problem was.
     
     
     If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
     
     If you encounter schema incompatibility errors during development, you can reduce their frequency by:
     * Simply deleting the existing store:
     [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
     
     * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
     [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
     
     Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
     
     */
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }
  
  return __persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

/**
 Returns the URL to the application's Documents directory.
 */
- (NSURL *)applicationDocumentsDirectory
{
  return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}



@end

#pragma mark -

@implementation OTPGoodTokenSheet

@synthesize authURL = authURL_;

- (void)dealloc {
  self.authURL = nil;
  [super dealloc];
}

@end
