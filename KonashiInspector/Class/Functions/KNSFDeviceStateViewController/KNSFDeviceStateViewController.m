//
//  KNSFDeviceStateViewController.m
//  KonashiInspector
//
//  Created by Akira Matsuda on 11/16/14.
//  Copyright (c) 2014 Akira Matsuda. All rights reserved.
//

#import "KNSFDeviceStateViewController.h"
#import "Konashi.h"
#import "SVProgressHUD.h"
#import "M2DWebViewController.h"

#define ConnectBackgroundColor [UIColor colorWithRed:0.000 green:0.478 blue:1.000 alpha:1.000]
#define DisconnectBackgroundColor [UIColor colorWithRed:0.987 green:0.173 blue:0.141 alpha:1.000]

@interface KNSFDeviceStateViewController ()
{
	__weak IBOutlet UILabel *nameLabel_;
	__weak IBOutlet UILabel *revisionLabel_;
	__weak IBOutlet UILabel *statusLabel_;
	__weak IBOutlet UILabel *rssiLabel_;
	__weak IBOutlet UILabel *batteryLabel_;
	__weak IBOutlet UIButton *connectButton_;
	__weak IBOutlet UIProgressView *rssiStrengthProgressBar_;
	__weak IBOutlet UIProgressView *batteryProgressBar_;
	__weak IBOutlet UIButton *batteryReadButton_;
	
	NSTimer *batteryReadRequestTimer_;
	NSTimer *rssiReadRequestTimer_;
}

@end

@implementation KNSFDeviceStateViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.title = @"Status";
	
	batteryReadButton_.layer.borderColor = batteryLabel_.tintColor.CGColor;
	batteryReadButton_.layer.borderWidth = 1;
	batteryReadButton_.layer.cornerRadius = 14;
	rssiStrengthProgressBar_.progress = 0;
	batteryProgressBar_.progress = 0;
	rssiLabel_.text = @"";
	batteryLabel_.text = @"";
	nameLabel_.text = @"Not connected";
	revisionLabel_.text = @"Not connected";
	statusLabel_.text = @"Not connected";
	connectButton_.layer.cornerRadius = 20;
	[connectButton_ setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[Konashi shared].connectedHandler = ^() {
		statusLabel_.text = @"Connected";
		[self updateControlState];
	};
	[Konashi shared].readyHandler = ^() {
		statusLabel_.text = @"Ready";
		[self updateControlState];
		rssiReadRequestTimer_ = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(readRSSI) userInfo:nil repeats:YES];
	};
	[Konashi shared].disconnectedHandler = ^() {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			nameLabel_.text = @"Not Connected";
			revisionLabel_.text = @"Not Connected";
			statusLabel_.text = @"Disconnected";
			batteryLabel_.text = @"";
			rssiLabel_.text = @"";
			[self updateControlState];
			rssiStrengthProgressBar_.progress = 0;
			batteryProgressBar_.progress = 0;
			[rssiReadRequestTimer_ invalidate];			
		});
	};
	[Konashi shared].signalStrengthDidUpdateHandler = ^(int value) {
		NSLog(@"RSSI did update:%d", value);
		if(value > 100.0){
			value = 100.0;
		}
		rssiLabel_.text = [NSString stringWithFormat:@"%3d db", value];
		rssiStrengthProgressBar_.progress = (CGFloat)value / 100 * -1;
	};
	[Konashi shared].batteryLevelDidUpdateHandler = ^(int value) {
		NSLog(@"battery level did update:%d", value);
		if(value > 100.0){
			value = 100.0;
		}
		batteryLabel_.text = [NSString stringWithFormat:@"%3d %%", value];
		batteryProgressBar_.progress = (CGFloat)value / 100;
	};
	
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventPeripheralFoundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[SVProgressHUD dismiss];
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventNoPeripheralsAvailableNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[SVProgressHUD dismiss];
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventDidFindSoftwareRevisionStringNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		revisionLabel_.text = [Konashi softwareRevisionString];
	}];
	
	[self updateControlState];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	[self updateControlState];
}

#pragma mark - 

- (void)readRSSI
{
	[Konashi signalStrengthReadRequest];
}

- (IBAction)readBattery:(id)sender
{
	[Konashi batteryLevelReadRequest];
}

- (IBAction)connect:(id)sender
{
	if ([Konashi isConnected]) {
		[Konashi disconnect];
	}
	else {
		[SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
		[Konashi reset];
		[Konashi find];
		rssiLabel_.text = @"";
		batteryLabel_.text = @"";
	}
}

- (void)updateControlState
{
	if ([Konashi isConnected]) {
		nameLabel_.text = [Konashi shared].activePeripheral.peripheral.name;
		statusLabel_.text = @"Connected";
		connectButton_.backgroundColor = DisconnectBackgroundColor;
		[connectButton_ setTitle:@"Disconnect" forState:UIControlStateNormal];
	}
	else {
		connectButton_.backgroundColor = ConnectBackgroundColor;
		[connectButton_ setTitle:@"Connect" forState:UIControlStateNormal];
	}
}

- (IBAction)showHelp:(id)sender
{
	M2DWebViewController *viewController = [[M2DWebViewController alloc] initWithURL:[NSURL URLWithString:@"http://konashi.ux-xu.com/getting_started/#first_touch"] type:M2DWebViewTypeUIKit];
	[viewController setHidesBottomBarWhenPushed:YES];
	[self.navigationController pushViewController:viewController animated:YES];
}

@end
