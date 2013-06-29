//
//  OTPAccount.m
//  OTPAuth
//
//  Created by Mark Guzman on 6/26/13.
//
//

#import "OTPAccount.h"


@implementation OTPAccount

@property (nonatomic, retain) OTPAuthUrl *url;

@dynamic name;
@dynamic url;
@dynamic sortRank;
@dynamic dateAdded;
@dynamic dateUpdated;
@dynamic tag;

- (OTPAuthURL *)asAuthUrl() {
  return nil;
}

@end
