//
//  OTKLogger.m
//  testreconnection
//
//  Created by Roberto Perez Cubero on 13/04/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

#import "OTKLogger.h"
@interface OpenTokObjC : NSObject
+ (void)setLogBlock:(void (^)(NSString* message, void* arg))aLogBlock;
+ (void)setLogBlockQueue:(dispatch_queue_t)queue;
@end

enum otk_enable_webrtc_trace_levels
{
    otk_enable_webrtc_trace_all,
    otk_enable_webrtc_trace_none
};
extern void otk_enable_webrtc_trace(enum otk_enable_webrtc_trace_levels level);

@implementation OTKLogger
+ (void)startLogger {
    [OpenTokObjC setLogBlockQueue:dispatch_get_main_queue()];
    [OpenTokObjC setLogBlock:^(NSString *message, void *arg) {
        NSLog(@"%@", message);
    }];
}

+ (void)enableWebrtcLogs {
    otk_enable_webrtc_trace(otk_enable_webrtc_trace_all);
}
@end
