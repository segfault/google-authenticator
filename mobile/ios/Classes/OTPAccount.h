//
//  OTPAccount.h
//  OTPAuth
//
//  Created by Mark Guzman on 6/26/13.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <TICoreDataSync.h>
#import "OTPAuthUrl.h"


@interface OTPAccount : TICDSSynchronizedManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSNumber * sortRank;
@property (nonatomic, retain) NSDate * dateAdded;
@property (nonatomic, retain) NSDate * dateUpdated;
@property (nonatomic, retain) NSString * tag;

- (OTPAuthURL *)asAuthUrl;


@end
