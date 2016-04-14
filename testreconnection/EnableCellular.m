//
//  EnableCellular.m
//  testreconnection
//
//  Created by Roberto Perez Cubero on 14/04/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

#import "EnableCellular.h"
#import <Opentok/Opentok.h>

@interface OTSession (cellular)
+ (void) setCellularEnabled:(BOOL)enabled;
@end

@implementation EnableCellular
+ (void) setCellularEnabled:(BOOL)enabled {
    [OTSession setCellularEnabled:enabled];
}
@end
