//
//  RootViewController.m
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

#import "RootViewController.h"
#import "OTPAuthURL.h"
#import "HOTPGenerator.h"
#import "OTPTableViewCell.h"
#import "UIColor+MobileColors.h"
#import "OTPAuthBarClock.h"
#import "TOTPGenerator.h"
#import "GTMLocalizedString.h"
#import "OTPAccount.h"

@interface RootViewController ()
@property(nonatomic, readwrite, retain) OTPAuthBarClock *clock;
- (void)showCopyMenu:(UIGestureRecognizer *)recognizer;
@end

@implementation RootViewController
@synthesize clock = clock_;
@synthesize addItem = addItem_;
@synthesize legalItem = legalItem_;
@synthesize fetchedResultsController=__fetchedResultsController;
@synthesize managedObjectContext=__managedObjectContext;

- (void)dealloc {
  [self.clock invalidate];
  self.clock = nil;
  self.addItem = nil;
  self.legalItem = nil;
  [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    // On an iPad, support both portrait modes and landscape modes.
    return UIInterfaceOrientationIsLandscape(interfaceOrientation) ||
           UIInterfaceOrientationIsPortrait(interfaceOrientation);
  }
  // On a phone/pod, don't support upside-down portrait.
  return interfaceOrientation == UIInterfaceOrientationPortrait ||
         UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void)viewDidLoad {
  UITableView *view = (UITableView *)self.view;
  view.backgroundColor = [UIColor googleBlueBackgroundColor];

  UIButton *titleButton = [[[UIButton alloc] init] autorelease];
  [titleButton setTitle:GTMLocalizedString(@"Better Authenticator", nil)
               forState:UIControlStateNormal];
  UILabel *titleLabel = [titleButton titleLabel];
  titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
  if ([[[UIDevice currentDevice] systemVersion] compare:@"7.0" options:NSNumericSearch] == NSOrderedAscending) {
    titleLabel.shadowOffset = CGSizeMake(0.0, -1.0);
    [titleButton setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:0.5]
                            forState:UIControlStateNormal];
  } else {
    [titleButton setTitleColor:[UIColor googleBlueTextColor] forState:UIControlStateNormal];
  }
  titleButton.adjustsImageWhenHighlighted = NO;
  [titleButton sizeToFit];

  UINavigationItem *navigationItem = self.navigationItem;
  navigationItem.titleView = titleButton;
  self.clock = [[[OTPAuthBarClock alloc] initWithFrame:CGRectMake(0,0,30,30)
                                                period:[TOTPGenerator defaultPeriod]] autorelease];
  UIBarButtonItem *clockItem
    = [[[UIBarButtonItem alloc] initWithCustomView:clock_] autorelease];
  [navigationItem setLeftBarButtonItem:clockItem animated:NO];
  self.navigationController.toolbar.tintColor = [UIColor googleBlueBarColor];

  // UIGestureRecognizers are actually in the iOS 3.1.3 SDK, but are not
  // publicly exposed (and have slightly different method names).
  // Check to see it the "public" version is available, otherwise don't use it
  // at all. numberOfTapsRequired does not exist in 3.1.3.
  if ([UITapGestureRecognizer
       instancesRespondToSelector:@selector(numberOfTapsRequired)]) {
    UILongPressGestureRecognizer *gesture =
        [[[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                       action:@selector(showCopyMenu:)]
         autorelease];
    [view addGestureRecognizer:gesture];
    UITapGestureRecognizer *doubleTap =
        [[[UITapGestureRecognizer alloc] initWithTarget:self
                                                 action:@selector(showCopyMenu:)]
         autorelease];
    doubleTap.numberOfTapsRequired = 2;
    [view addGestureRecognizer:doubleTap];
  }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
  [super setEditing:editing animated:animated];
  self.addItem.enabled = !editing;
  self.legalItem.enabled = !editing;
}

- (void)showCopyMenu:(UIGestureRecognizer *)recognizer {
  BOOL isLongPress =
      [recognizer isKindOfClass:[UILongPressGestureRecognizer class]];
  if ((isLongPress && recognizer.state == UIGestureRecognizerStateBegan) ||
      (!isLongPress && recognizer.state == UIGestureRecognizerStateRecognized)) {
    CGPoint location = [recognizer locationInView:self.view];
    UITableView *view = (UITableView*)self.view;
    NSIndexPath *indexPath = [view indexPathForRowAtPoint:location];
    UITableViewCell* cell = [view cellForRowAtIndexPath:indexPath];
    if ([cell respondsToSelector:@selector(showCopyMenu:)]) {
      location = [view convertPoint:location toView:cell];
      [(OTPTableViewCell*)cell showCopyMenu:location];
    }
  }
}

#pragma mark -
#pragma mark Cell Display
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
  OTPAccount *acct = [self.fetchedResultsController objectAtIndexPath:indexPath];
  OTPTableViewCell *otpCell = (OTPTableViewCell*)cell;
  OTPAuthURL *authUrl = [acct asAuthUrl];
  [otpCell setAuthURL:authUrl];
}

#pragma mark -
#pragma mark Table View Data Source and Delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
  return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *CellIdentifier = @"Cell";
  
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
  }
  
  [self configureCell:cell atIndexPath:indexPath];
  return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (editingStyle == UITableViewCellEditingStyleDelete)
  {
    // Delete the managed object for the given index path
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
    
    // Save the context.
    NSError *error = nil;
    if (![context save:&error])
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

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
  // The table view should not be re-orderable.
  return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  OTPAccount *acct = [[self fetchedResultsController] objectAtIndexPath:indexPath];
  
  OTPTableViewCell *otpCell = [[OTPTableViewCell alloc] init];
  [otpCell setAuthURL: [acct asAuthUrl]];
}

#pragma mark -
#pragma mark Insertion
- (void)insertNewObject
{
  // Create a new instance of the entity managed by the fetched results controller.
  NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
  NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
  OTPAccount *newAccount = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
  
  [newAccount setName:@"New OTP"];
  [newAccount setUrl:@""];
  
  // Save the context.
  NSError *error = nil;
  if (![context save:&error])
  {
    /*
     Replace this implementation with code to handle the error appropriately.
     
     abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
     */
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
  }
}


#pragma mark - NSPersistentStoreCoordinatorStoresDidChangeNotification method

- (void)persistentStoresDidChange:(NSNotification *)aNotification
{
  NSError *anyError = nil;
  BOOL success = [self.fetchedResultsController performFetch:&anyError];
  if (success == NO) {
    NSLog(@"Error fetching: %@", anyError);
  }
  
  [self.tableView reloadData];
}

#pragma mark - Fetched results controller
- (NSFetchedResultsController *)fetchedResultsController
{
  if (__fetchedResultsController != nil)
  {
    return __fetchedResultsController;
  }
  
  /*
   Set up the fetched results controller.
   */
  // Create the fetch request for the entity.
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  // Edit the entity name as appropriate.
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"OTPAccount" inManagedObjectContext:self.managedObjectContext];
  [fetchRequest setEntity:entity];
  
  // Set the batch size to a suitable number.
  [fetchRequest setFetchBatchSize:20];
  
  // Edit the sort key as appropriate.
  NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
  NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
  
  [fetchRequest setSortDescriptors:sortDescriptors];
  
  // Edit the section name key path and cache name if appropriate.
  // nil for section name key path means "no sections".
  NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Root"];
  aFetchedResultsController.delegate = self;
  self.fetchedResultsController = aFetchedResultsController;
  
  [aFetchedResultsController release];
  [fetchRequest release];
  [sortDescriptor release];
  [sortDescriptors release];
  
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error])
  {
    /*
     Replace this implementation with code to handle the error appropriately.
     
     abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
     */
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
	}
  
  return __fetchedResultsController;
}

#pragma mark - Fetched results controller delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
  [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
  switch(type)
  {
    case NSFetchedResultsChangeInsert:
      [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
      break;
      
    case NSFetchedResultsChangeDelete:
      [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
      break;
  }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
  UITableView *tableView = self.tableView;
  
  switch(type)
  {
      
    case NSFetchedResultsChangeInsert:
      [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
      break;
      
    case NSFetchedResultsChangeDelete:
      [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
      break;
      
    case NSFetchedResultsChangeUpdate:
      [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
      break;
      
    case NSFetchedResultsChangeMove:
      [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
      [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]withRowAnimation:UITableViewRowAnimationFade];
      break;
  }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
  [self.tableView endUpdates];
}

@end

