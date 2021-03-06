//
//  User.m
//  top_this
//
//  Created by Andrew Benson on 2/1/13.
//  Copyright (c) 2013 Andrew Benson. All rights reserved.
//

#import "User.h"

@implementation User

@synthesize userId = _userId;
@synthesize firstName = _firstName;
@synthesize lastName = _lastName;
@synthesize email = _email;
@synthesize adminId = _adminId;
@synthesize photoData = _photoData;
@synthesize profilePicURL = _profilePicURL;
@synthesize fullName = _fullName;
@synthesize createdAt = _createdAt;

-(NSString *)fullName{
    return [NSString stringWithFormat:@"%@ %@", self.firstName, self.lastName];
}

@end
