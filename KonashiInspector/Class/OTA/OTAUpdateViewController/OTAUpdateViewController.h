//
//  OTAUpdateViewController.h
//  KonashiJs
//
//  Created by Akira Matsuda on 11/4/14.
//  Copyright (c) 2014 Yukai Engineering. All rights reserved.
//

#import <UIKit/UIKit.h>
@import CoreBluetooth;

@interface OTAUpdateViewController : UITableViewController //<CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic, copy)
NSString *firmwareFilename;

@property (nonatomic, copy)
NSString *peripheralName;

@property (nonatomic, copy)
NSString *peripheralNumbar;
@property (nonatomic, copy)
NSString *peripheralRevision;


@property
unsigned char *Array;
@property
double DataNum;
@property
int L;
@property
int Head;
@property
int Width;

@property
Boolean * KSH3isConnect;

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheral *peripheral;

@end
