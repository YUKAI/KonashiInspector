//
//  OTAUpdateViewController.m
//  KonashiJs
//
//  Created by Akira Matsuda on 11/4/14.
//  Copyright (c) 2014 Yukai Engineering. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "OTAUpdateViewController.h"
#import "OTAFirmwareTableViewController.h"
#import <CommonCrypto/CommonDigest.h>
#import "Konashi.h"
#import "Konashi+OTA.h"
#import "SVProgressHUD.h"

typedef NS_ENUM(NSUInteger, OTAStatus) {
	OTAStatusInitialized,
	OTAStatusWaiting,
	OTAStatusUpdating,
	OTAStatusFinished,
    
    DFU_MODE,
    DFU_START_MODE,
    DFU_NOW_UPDATE,
    DFU_UPDATE_FINISH,
    DFU_END,
    DFU_SECOND_OTA
};

@interface OTAUpdateViewController () <UIAlertViewDelegate>
{
    __block OTAStatus currentStatus;
    __block OTAStatus ksh3currentStatus;
	NSArray *contents;
	UIButton *selectButton;
	UIButton *connectButton;
	UIButton *updateButton;
	NSData *firmwareData;
    NSTimer *scan_timer;
    //peripheralを格納
    CBPeripheral *KONASHI3;
    CBPeripheral *KSH3;
    
    CBCharacteristic *CHARACTERISTICS_KONASHI3_OTA_DFU_TRANS;
    CBCharacteristic *CHARACTERISTICS_OTA_Control_Attribute;
    CBCharacteristic *CHARACTERISTICS_OTA_Data_Attribute;
    
    Boolean isFullData;
    NSString *at;
    NSString *appURL;
    NSString *stackURL;
}

@end

@implementation OTAUpdateViewController

static NSString *const KONASHI_UUID = @"D30EA642-ECDF-4AAC-AB2C-734A0E64A6DD";
static NSString *const DFU_UUID =     @"46891226-7810-4312-BDA5-3AA6430F79CD";
static NSString *const SERVICE_OTA_MODE_TRANS_UUID =       @"1D14D6EE-FD63-4FA1-BFA4-8F47B42119F0";
static NSString *const SERVICE_OTA_MODE_OTA_CONTROL_UUID = @"1D14D6EE-FD63-4FA1-BFA4-8F47B42119F0";
static NSString *const KONASHI3_OTA_DFU_TRANS_UUID =       @"F7BF3564-FB6D-4E53-88A4-5E37E0326063";
static NSString *const OTA_Control_Attribute_UUID =        @"F7BF3564-FB6D-4E53-88A4-5E37E0326063";
static NSString *const OTA_Data_Attribute_UUID =           @"984227F3-34FC-4045-A5D0-2C581F81A153";
static NSString *const KONASHI3_OTA_NAME =                 @"ksh3-ota";

static Byte const KONASHI3_DFU_MODE = 1;
static Byte const KONASHI3_NORMAL_MODE = 0;
static Byte const KONASHI3_FINISH_OTA_UPDATE = 2;

static Byte const KONASHI3_OTA_DFU_TRANS_COMMAND =  0x01;
static Byte const OTA_UPDATE_START_COMMAND  = 0x00;
static Byte const OTA_UPDATE_FINISH_COMMAND  = 0x03;

- (void)viewDidLoad
{
	[super viewDidLoad];
    isFullData = false;
	self.title = @"OTA Update";
	self.tableView.estimatedRowHeight = 60;
	contents = @[@{
				  @"title":@"ファームウェア",
				  @"content":@[
						  @"Title"
						  ]
				  },
				 @{
				  @"title":@"対象",
				  @"content":@[
						  @"Name",
						  @"Revision"
						  ]
				  },
				 @{}
				 ];
	[[NSNotificationCenter defaultCenter] addObserverForName:KONASHI_OTA_FINISH_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		currentStatus = OTAStatusFinished;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"アップデートが完了しました。" message:@"Konashiは自動的にリセットされます。FWによってはリセットに電源の再供給が必要な場合がありますので、再度Connectを押してリストアップされない場合は試してみてください。" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[SVProgressHUD dismiss];
		});
	}];
    [[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventReadyToUseNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        self.peripheralName = [Konashi peripheralName];
        if ([self isKonashi3:[self peripheralName]]) {
            NSArray* values = [self.peripheralName componentsSeparatedByString:@"-"];
            self.peripheralNumbar = values[1];
        }else {
            if (currentStatus == OTAStatusWaiting) {
                [self uploadFirmwareData];
            }
        }
        [[self tableView] reloadData];
    }];
    [[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventDisconnectedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [self startScan];
    }];
	[[NSNotificationCenter defaultCenter] addObserverForName:KONASHI_OTA_ERROR_NOTIFICATION object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		currentStatus = OTAStatusFinished;
		NSError *error = note.object;
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Error(code=%ld)", (long)error.code] message:error.localizedDescription delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[SVProgressHUD dismiss];
		});
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventConnectedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[SVProgressHUD dismiss];
		[self updateButtonState];
		[self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:1]] withRowAnimation:UITableViewRowAnimationFade];
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventDisconnectedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		if (currentStatus == OTAStatusUpdating) {
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"失敗しました" message:@"ファームウェアアップデートを完了できませんでした。リトライされる場合には、デバイスへの給電が安定していること、iOSデバイスとの距離が1m以内程度で遮蔽がないことを確認してください。" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert show];
		}
		[SVProgressHUD dismiss];
		[self updateButtonState];
		[self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:1], [NSIndexPath indexPathForRow:1 inSection:1]] withRowAnimation:UITableViewRowAnimationFade];
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventPeripheralFoundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[SVProgressHUD dismiss];
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventNoPeripheralsAvailableNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[SVProgressHUD dismiss];
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:OTAFirmwareSelectedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		NSString *filename = note.userInfo[@"filename"];
		self.firmwareFilename = filename;
        NSLog(@"%@",filename);
        if([filename hasSuffix:@".bin"] || [filename hasSuffix:@".ebl"]){
            firmwareData = note.userInfo[@"data"];
            isFullData = false;
        }else{
            isFullData = true;
            if([note.userInfo[@"at"] hasPrefix:@"iTunes"]){
                NSArray *documentDirectries = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentDirectory = [documentDirectries lastObject];
                NSString *s = [NSString stringWithFormat:@"%@/%@",documentDirectory,filename];
                NSFileManager *iTunesFileManager = [NSFileManager defaultManager];
                for(NSString *file in [iTunesFileManager contentsOfDirectoryAtPath:s error:nil]){
                    if([self isStackDfu:file]){
                        NSLog(@"%@",file);
                        firmwareData = [[NSData alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@",s,file]];
                        break;
                    }
                }
                Boolean error = false;
                for(NSString *file in [iTunesFileManager contentsOfDirectoryAtPath:s error:nil]){
                    if(![self isStackDfu:file] || ![self isAppDfu:file]){
                        error |= true;
                    }
                }
                if(error == false){
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"失敗しました" message:[NSString stringWithFormat:@"stack.eblとapp.eblが%@に入っていることの確認およびファイル名をご確認ください。",filename] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [alert show];
                }
            }else if([note.userInfo[@"at"] hasPrefix:@"server"]){
                stackURL = note.userInfo[@"stack_url"];
                appURL = note.userInfo[@"app_url"];
                at = note.userInfo[@"at"];
                NSString *str = stackURL;
                [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
                [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:str]] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                    if (connectionError == nil) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            firmwareData = data;
                            [self dismissViewControllerAnimated:YES completion:^{
                            }];
                        });
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [SVProgressHUD dismiss];
                    });
                }];
            }
        }
        [self updateButtonState];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0], [NSIndexPath indexPathForRow:0 inSection:1]] withRowAnimation:UITableViewRowAnimationFade];
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventDidFindSoftwareRevisionStringNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:1]] withRowAnimation:UITableViewRowAnimationFade];
	}];
	currentStatus = OTAStatusInitialized;
    ksh3currentStatus = OTAStatusInitialized;
	[Konashi initialize];
}

- (void)peripheral:(CBPeripheral *)peripheral
didDisconnectPeripheral:(CBService *)service
             error:(NSError *)error
{
    
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [contents count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return section < [contents count] - 1 ? [contents[section][@"content"] count] : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *const reuseIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:reuseIdentifier];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
		cell.detailTextLabel.numberOfLines = 0;
	}
	NSArray *item = contents[indexPath.section][@"content"];
	cell.textLabel.text = item[indexPath.row];
	cell.detailTextLabel.text = [self detailStringAtIndexPath:indexPath];
	
	return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return contents[section][@"title"];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
	UIView *view = nil;
	if (section == 0) {
		if (selectButton == nil) {
			selectButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
			[selectButton setTitle:@"Select firmware" forState:UIControlStateNormal];
			[selectButton setBackgroundColor:[UIColor colorWithRed:0.000 green:0.478 blue:1.000 alpha:1.000]];
			[selectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
			[selectButton addTarget:self action:@selector(selectFirmware:) forControlEvents:UIControlEventTouchUpInside];
		}
		view = selectButton;
	}
	else if (section == 1) {
		if (connectButton == nil) {
			connectButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
			[connectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
			[connectButton addTarget:self action:@selector(connectKonashi:) forControlEvents:UIControlEventTouchUpInside];
		}

		if ([Konashi isConnected]) {
			[connectButton setBackgroundColor:[UIColor colorWithRed:0.987 green:0.173 blue:0.141 alpha:1.000]];
			[connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
		}
		else {
			[connectButton setBackgroundColor:[UIColor colorWithRed:0.000 green:0.478 blue:1.000 alpha:1.000]];
			[connectButton setTitle:@"Connect" forState:UIControlStateNormal];
		}
		view = connectButton;
	}
	else if (section == contents.count - 1) {
		if (updateButton == nil) {
			updateButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
			[updateButton setTitle:@"Update" forState:UIControlStateNormal];
			[updateButton setBackgroundColor:[UIColor colorWithRed:0.000 green:0.478 blue:1.000 alpha:1.000]];
			[updateButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
			[updateButton addTarget:self action:@selector(updateFirmware:) forControlEvents:UIControlEventTouchUpInside];
        }self.peripheralName = [Konashi peripheralName];
        bool iskonashi3 = [self isKonashi3:_firmwareFilename] == true && [self isKonashi3:_peripheralName] == true;
        bool iskonashi2 = [self isKonashi2:_firmwareFilename] == true && [self isKonashi2:_peripheralName] == true;
		updateButton.enabled = (self.firmwareFilename != nil
                                && [Konashi isConnected] == YES) && (iskonashi2 || iskonashi3);
        if (updateButton.enabled == NO ) {
			[updateButton setBackgroundColor:[UIColor colorWithRed:0.000 green:0.478 blue:1.000 alpha:0.500]];
		}
		else {
            [updateButton setBackgroundColor:[UIColor colorWithRed:0.000 green:0.478 blue:1.000 alpha:1.000]];
		}

		view = updateButton;
	}
	
	return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
	return 45;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == 1) {
        [self uploadFirmwareData];
        
	}
}

#pragma mark -

- (NSString *)detailStringAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *detailString = nil;
	if (indexPath.section == 0) {
		if (self.firmwareFilename == nil) {
			detailString = @"Not selected.";
		}
		else {
			detailString = self.firmwareFilename;
		}
	}
	else if (indexPath.section == 1) {
        if ([Konashi isConnected] == NO) {
			detailString = @"Not connected";
		}
		else {
			if (indexPath.row == 0) {
				detailString = [Konashi peripheralName];
			}
			else {
                _peripheralRevision = [Konashi shared].activePeripheral.softwareRevisionString;
                detailString = _peripheralRevision;
			}
		}
	}
	
	return detailString;
}

- (void)updateButtonState
{
    bool iskonashi3 = [self isKonashi3:_firmwareFilename] == true && [self isKonashi3:_peripheralName] == true;
    bool iskonashi2 = [self isKonashi2:_firmwareFilename] == true && [self isKonashi2:_peripheralName] == true;
    updateButton.enabled = (self.firmwareFilename != nil
                            && [Konashi isConnected] == YES) && (iskonashi2 || iskonashi3);
	if (updateButton.enabled == NO) {
		[updateButton setBackgroundColor:[UIColor colorWithRed:0.000 green:0.478 blue:1.000 alpha:0.500]];
	}
	else {
		[updateButton setBackgroundColor:[UIColor colorWithRed:0.000 green:0.478 blue:1.000 alpha:1.000]];
	}
	if ([Konashi isConnected]) {
		[connectButton setBackgroundColor:[UIColor colorWithRed:0.987 green:0.173 blue:0.141 alpha:1.000]];
		[connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
	}
	else {
		[connectButton setBackgroundColor:[UIColor colorWithRed:0.000 green:0.478 blue:1.000 alpha:1.000]];
		[connectButton setTitle:@"Connect" forState:UIControlStateNormal];
	}
}

- (void)selectFirmware:(id)sender
{
	OTAFirmwareTableViewController *viewController = [[OTAFirmwareTableViewController alloc] initWithStyle:UITableViewStylePlain];
	UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
	navigationController.navigationBar.translucent = YES;
	[self presentViewController:navigationController animated:YES completion:^{
	}];
}

- (void)updateFirmware:(id)sender
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"注意" message:@"ファームウェアアップデートの途中でBLE通信が中断されると、Konashiが正常に動作しなくなり、OTAでの復帰が不可能になります。Konashiへの給電が安定していること、iOSデバイスの電池残量が十分であること、距離が1m以内程度で遮蔽がないこと、妨害者が居ないことなどを確認の上、ユーザの責任においてアップデートを実施してください。OTAで復帰不能になった場合は有線で復帰いただけます。詳細はwww.m-pression.comのkoshianサイトをご覧ください。なお、復帰作業はユカイ工学およびマクニカ・テクスターカンパニーでは承っておりません。ご理解のほどよろしくお願いいたします。（アップデートには40秒ほどかかります。また、アップデートの前後でDEVICE_NAMEの後半6桁は保持されます。）" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
	[alert show];
}

- (void)connectKonashi:(id)sender
{
	if ([Konashi isConnected] ) {
		[Konashi disconnect];
        
	}
	else {
		[SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
		[Konashi find];
	}
}

- (void)uploadFirmwareData
{
	if ([Konashi isReady] == NO) {
		[SVProgressHUD showWithStatus:@"Waiting..." maskType:SVProgressHUDMaskTypeGradient];
		currentStatus = OTAStatusWaiting;
	}
	else {
        ksh3currentStatus = OTAStatusInitialized;
        if([_peripheralName hasPrefix:@"konashi3"]){
            [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
            _peripheral = [[[Konashi shared] activePeripheral] peripheral];
            [_peripheral discoverServices:nil];
            for (CBService *service in _peripheral.services){
                NSLog(@"%lu個のキャラスタティックを見つけた",[service.characteristics count]);
                for (CBCharacteristic *characteristic in service.characteristics )
                {
                    if (ksh3currentStatus == OTAStatusInitialized && [characteristic.UUID isEqual:[CBUUID UUIDWithString:KONASHI3_OTA_DFU_TRANS_UUID]] ) {
                        
                        NSLog(@"%@", characteristic);
                        CHARACTERISTICS_KONASHI3_OTA_DFU_TRANS = characteristic;
                        NSLog(@"KONASHI3 OTA DFU TRANS を発見");
                        
                        Byte value  = 0;
                        NSData *data = [NSData dataWithBytes:&value length:sizeof(Byte)];
                        NSLog(@"%@",data);
                        [_peripheral writeValue:data forCharacteristic:CHARACTERISTICS_KONASHI3_OTA_DFU_TRANS type:CBCharacteristicWriteWithResponse];
                        ksh3currentStatus = DFU_MODE;
                        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
                        return;
                    }
                }
            }
        }
        else{
            if (firmwareData) {
                currentStatus = OTAStatusUpdating;
                [[Konashi shared] setOta_progressBlock:^(CGFloat progress, NSString *status) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        currentStatus = OTAStatusUpdating;
                        if (progress == -1) {
                            [SVProgressHUD showWithStatus:status maskType:SVProgressHUDMaskTypeGradient];
                        }
                        else if (progress == 1) {
                            [SVProgressHUD showSuccessWithStatus:status];
                            currentStatus = OTAStatusFinished;
                        }
                        else {
                            [SVProgressHUD showProgress:progress status:status maskType:SVProgressHUDMaskTypeGradient];
                        }
                    });
                }];
                
                [[Konashi shared] ota_updateFirmware:firmwareData];
            }
            else {
                [SVProgressHUD showErrorWithStatus:@"Invalid data"];
            }
        }
	}
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
    NSLog(@"state:%ld", (long)central.state);
}
- (void)   centralManager:(CBCentralManager *)central
  didDisconnectPeripheral:(nonnull CBPeripheral *)peripheral error:(nullable NSError *)error
{
    [self updateButtonState];
}
- (void)   centralManager:(CBCentralManager *)central
    didDiscoverPeripheral:(CBPeripheral *)peripheral
        advertisementData:(NSDictionary *)advertisementData
                     RSSI:(NSNumber *)RSSI
{
    NSLog(@"peripheral：%@", peripheral);
    if([[peripheral name] hasPrefix:KONASHI3_OTA_NAME] == true && ksh3currentStatus == DFU_MODE){
        //   scanBtn.isOn = false
        NSLog(@"ksh3　見つけました。");
        KSH3 = peripheral;
        // 接続開始
        [central connectPeripheral:KSH3 options:nil];
        [central stopScan];
    }else if([[peripheral name] hasPrefix:KONASHI3_OTA_NAME] == true &&  ksh3currentStatus == DFU_SECOND_OTA ){
        //   scanBtn.isOn = false
        NSLog(@"ksh3　見つけました。");
        KSH3 = peripheral;
        // 接続開始
        [central connectPeripheral:KSH3 options:nil];
        [central stopScan];
    }
}
// ペリフェラルへの接続が成功すると呼ばれる
- (void)  centralManager:(CBCentralManager *)central
    didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"connected!");
    peripheral.delegate = self;
    [peripheral discoverServices:nil];
}
- (void) peripheral:(CBPeripheral *)peripheral
    didDiscoverServices:(NSError *)error
{
    if (error) {
        NSLog(@"error: %@", error);
        return;
    }
    
    NSArray *services = peripheral.services;
    for(CBService *service in services ){
        [peripheral discoverCharacteristics:nil forService:service];
    }
    NSLog(@"Found %lu services! :%@", (unsigned long)services.count, services);
}
- (void)  peripheral:(CBPeripheral *)peripheral
    didDiscoverCharacteristicsForService:(CBService *)service
                                   error:(NSError *)error
{
    if (error) {
        NSLog(@"error: %@", error);
        return;
    }
    int fund = 0;
    NSLog(@"%lu個のキャラスタティックを見つけた",[service.characteristics count]);
    for (CBCharacteristic *characteristic in service.characteristics )
    {
        NSLog(@"%@",characteristic);
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:OTA_Data_Attribute_UUID]]) {
            NSLog(@"OTA Data Attribute UUID を発見");
            CHARACTERISTICS_OTA_Data_Attribute = characteristic;
            fund += 1;
        }else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:OTA_Control_Attribute_UUID]]) {
            NSLog(@"OTA Control Attribute UUID を発見");
            CHARACTERISTICS_OTA_Control_Attribute = characteristic;
            fund += 1;
        }
    }
    if(fund == 2){
        _Array = (unsigned char *)[firmwareData bytes];
        _DataNum = [firmwareData length];
        _L = 0;
        _Head = 0;
        _Width = 100;
        NSLog(@"%f %s",_DataNum,_Array);
        Byte tempVal = OTA_UPDATE_START_COMMAND;
        NSData *tempNS = [NSData dataWithBytes:&tempVal length:sizeof(tempVal)];
        ksh3currentStatus = DFU_START_MODE;
        [KSH3 writeValue:tempNS forCharacteristic:CHARACTERISTICS_OTA_Control_Attribute type:CBCharacteristicWriteWithResponse];
    }
    NSLog(@"Found %lu characteristics! : %@", (unsigned long)service.characteristics.count, service.characteristics);
}

- (void) peripheral:(CBPeripheral *)peripheral
            didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
              error:(NSError *)error
{
    if (error) {
        NSLog(@"Write失敗...error:%@", error);
        [SVProgressHUD dismiss];
        [[UIApplication sharedApplication] endIgnoringInteractionEvents] ;
        ksh3currentStatus = OTAStatusInitialized;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"失敗しました" message:@"ファームウェアアップデートを完了できませんでした。リトライされる場合には、デバイスへの給電が安定していること、iOSデバイスとの距離が1m以内程度で遮蔽がないことを確認してください。" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        return;
    }
UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"アップデートが完了しました。" message:@"Konashiは自動的にリセットされます。FWによってはリセットに電源の再供給が必要な場合がありますので、再度Connectを押してリストアップされない場合は試してみてください。" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    Byte tempVal = 0;
    NSData *tempNS;
    switch (ksh3currentStatus) {
        //DFUスタートフラグ
    case DFU_START_MODE:
        NSLog(@"DFU_START_MODE");
        ksh3currentStatus = DFU_NOW_UPDATE;
        break;
        //DFU終了フラグ
    case DFU_END:
        NSLog(@"ota End");
        [_centralManager cancelPeripheralConnection:KSH3];
        if(isFullData == true && ![self isAppDfu:_firmwareFilename]){
            isFullData = false;
            [SVProgressHUD showWithStatus:@"Reconnecting..." maskType:SVProgressHUDMaskTypeGradient];
            ksh3currentStatus = DFU_SECOND_OTA;
            
            if([at hasPrefix:@"server"]){
                [SVProgressHUD showWithStatus:@"Download image file..." maskType:SVProgressHUDMaskTypeGradient];
                [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:appURL]] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                    if (connectionError == nil) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            firmwareData = data;
                            [self dismissViewControllerAnimated:YES completion:^{
                            }];
                        });
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_centralManager connectPeripheral:KSH3 options:nil];
                    });
                }];
            }else{
                NSArray *documentDirectries = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentDirectory = [documentDirectries lastObject];
                NSString *s = [NSString stringWithFormat:@"%@/%@",documentDirectory,_firmwareFilename];
                NSFileManager *iTunesFileManager = [NSFileManager defaultManager];
                for(NSString *file in [iTunesFileManager contentsOfDirectoryAtPath:s error:nil]){
                    if([self isAppDfu:file]){
                        NSLog(@"%@",file);
                        firmwareData = [[NSData alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@",s,file]];
                        break;
                    }
                }
                [_centralManager connectPeripheral:KSH3 options:nil];
            }
        }else{
            NSLog(@"ota アップデート完了");
            [SVProgressHUD dismiss];
            [alert show];
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            ksh3currentStatus = OTAStatusInitialized;
            if (![self isStackDfu:_firmwareFilename]) {
                isFullData = true;
                
                if([at hasPrefix:@"server"]){
                    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:stackURL]] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                        if (connectionError == nil) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                firmwareData = data;
                                [self dismissViewControllerAnimated:YES completion:^{
                                }];
                            });
                        }
                    }];
                }else{
                    NSArray *documentDirectries = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                    NSString *documentDirectory = [documentDirectries lastObject];
                    NSString *s = [NSString stringWithFormat:@"%@/%@",documentDirectory,_firmwareFilename];
                    NSFileManager *iTunesFileManager = [NSFileManager defaultManager];
                    for(NSString *file in [iTunesFileManager contentsOfDirectoryAtPath:s error:nil]){
                        if([self isStackDfu:file]){
                            NSLog(@"%@",file);
                            firmwareData = [[NSData alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@",s,file]];
                            break;
                        }
                    }
                }
            }
        }
        break;
        //DFU中フラグ
    case DFU_UPDATE_FINISH:
            NSLog(@"DFU_UPDATE_FINISH");
        tempVal  = OTA_UPDATE_FINISH_COMMAND;
        tempNS = [NSData dataWithBytes:&tempVal length:sizeof(tempVal)];
        [KSH3 writeValue:tempNS forCharacteristic:CHARACTERISTICS_OTA_Control_Attribute type:CBCharacteristicWriteWithResponse];

        ksh3currentStatus = DFU_END;
        break;
        
    default:
        NSLog(@"end");
        break;
    }
    
    //OTAアップデート
    if (ksh3currentStatus == DFU_NOW_UPDATE){
        NSLog(@"DFU_NOW_UPDATE");
        double parcent = (_Head) / (_DataNum);
        NSString *str = [NSString stringWithFormat:@"%@ uploading...", isFullData == true ? @"Stack" : @"App"];
        [SVProgressHUD showProgress:parcent status:str maskType:SVProgressHUDMaskTypeGradient];
        if( (_DataNum  - _Head) > _Width ) {
            _L = _Width;
        }else if ((_DataNum  - _Head)  <= _Width){
            _L = (_DataNum  - _Head);
            ksh3currentStatus = DFU_UPDATE_FINISH;
        }
        //let kbData = [firmwareData] subdata(in: head..<L + head)
        NSData *kbData = [firmwareData subdataWithRange:NSMakeRange(_Head, _L)];
        NSLog(@"@%@",kbData);
        _Head += _L;
        NSLog(@"%d",_Head);
        [KSH3 writeValue:kbData forCharacteristic:CHARACTERISTICS_OTA_Data_Attribute type:CBCharacteristicWriteWithResponse];
        
    }
}
- (void)startScan
{
    [SVProgressHUD showWithStatus:@"Preparing..." maskType:SVProgressHUDMaskTypeGradient];
    // Bluetooth related code
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    scan_timer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(stopScan) userInfo:nil repeats:YES];
}

// Stops the Scanning and Timer
- (void)stopScan
{
    [SVProgressHUD dismiss];
    [self.centralManager stopScan];
    [scan_timer invalidate];
    scan_timer = nil;
}

- (Boolean)isKonashi3:(NSString*)name
{
    return [name hasPrefix:@"konashi3"];
}
- (Boolean)isKsh3:(NSString*)name
{
    return [name hasPrefix:@"Ksh3"];
}
- (Boolean)isKoshianID:(NSString*)name
{
    return [name hasPrefix:_peripheralNumbar];
}
- (Boolean)isKonashi2:(NSString*)name
{
    return [name hasPrefix:@"konashi2"];
}
- (Boolean)isAppDfu:(NSString*)name
{
    return [[name lowercaseString] containsString:@"app"];
}
- (Boolean)isStackDfu:(NSString*)name
{
    return [[name lowercaseString] containsString:@"stack"];
}



@end
