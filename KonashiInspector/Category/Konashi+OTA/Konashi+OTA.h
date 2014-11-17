//
//  Konashi+OTA.h
//  KonashiJs
//
//  Created by Akira Matsuda on 11/5/14.
//  Copyright (c) 2014 Yukai Engineering. All rights reserved.
//

#import "Konashi.h"

#define KONASHI_OTA_FINISH_NOTIFICATION @"KONASHI_OTA_FINISH_NOTIFICATION"
#define KONASHI_OTA_ERROR_NOTIFICATION @"KONASHI_OTA_ERROR_NOTIFICATION"

@interface Konashi (OTA)

- (void)ota_updateFirmware:(NSData *)data;
- (void)setOta_progressBlock:(void (^)(CGFloat progress, NSString *status))block;

@end
