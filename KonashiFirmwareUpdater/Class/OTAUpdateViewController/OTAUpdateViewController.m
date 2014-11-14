//
//  OTAUpdateViewController.m
//  KonashiJs
//
//  Created by Akira Matsuda on 11/4/14.
//  Copyright (c) 2014 Yukai Engineering. All rights reserved.
//

#import "OTAUpdateViewController.h"
#import "OTAFirmwareTableViewController.h"
#import <CommonCrypto/CommonDigest.h>
#import "Konashi.h"
#import "Konashi+OTA.h"
#import "SVProgressHUD.h"

#define KONASHI_DEBUG 1

typedef NS_ENUM(NSUInteger, OTAStatus) {
	OTAStatusInitialized,
	OTAStatusWaiting,
	OTAStatusUpdating,
	OTAStatusFinished
};

@interface OTAUpdateViewController () <UIAlertViewDelegate>
{
	__block OTAStatus currentStatus;
	NSArray *contents;
	UIButton *selectButton;
	UIButton *connectButton;
	UIButton *updateButton;
}

@end

@implementation OTAUpdateViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
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
#if 1
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"アップデートが完了しました。" message:@"Konashiは自動的にリセットされます。FWによってはリセットに電源の再供給が必要な場合がありますので、再度Connectを押してリストアップされない場合は試してみてください。" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
#else
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Successfully updated!" message:@"Normally, Konashi reboots automatially. Some firmwares need re-powering, so please try when it won't show up in the list displayed when you tap the Connect button again." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
#endif
		[alert show];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[SVProgressHUD dismiss];
		});
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventReadyToUseNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		if (currentStatus == OTAStatusWaiting) {
			[self uploadFirmwareData];
		}
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
		NSString *filename = note.object;
		self.firmwareFilename = filename;
		[self updateButtonState];
		[self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0], [NSIndexPath indexPathForRow:0 inSection:1]] withRowAnimation:UITableViewRowAnimationFade];
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventDidFindSoftwareRevisionStringNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:1]] withRowAnimation:UITableViewRowAnimationFade];
	}];	
	currentStatus = OTAStatusInitialized;
	[Konashi initialize];
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
		}
		updateButton.enabled = (self.firmwareFilename != nil && [Konashi isConnected] == YES);
		if (updateButton.enabled == NO) {
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
				detailString = [Konashi shared].activePeripheral.softwareRevisionString;
			}
		}
	}
	
	return detailString;
}

- (void)updateButtonState
{
	updateButton.enabled = (self.firmwareFilename != nil && [Konashi isConnected] == YES);
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
#if 1
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"注意" message:@"ファームウェアアップデートの途中でBLE通信が中断されると、Konashiが正常に動作しなくなり、OTAでの復帰が不可能になります。Konashiへの給電が安定していること、iOSデバイスの電池残量が十分であること、距離が1m以内程度で遮蔽がないこと、妨害者が居ないことなどを確認の上、ユーザの責任においてアップデートを実施してください。OTAで復帰不能になった場合は有線で復帰いただけます。詳細はwww.m-pression.comのkoshianサイトをご覧ください。なお、復帰作業はユカイ工学およびマクニカ・テクスターカンパニーでは承っておりません。ご理解のほどよろしくお願いいたします。（アップデートには40秒ほどかかります。また、アップデートの前後でDEVICE_NAMEの後半6桁は保持されます。）" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
#else
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Caution" message:@"Update may take around 40 seconds. When it's interrupted, Konashi won't work properly again and couldn't be recovered via OTA. Before going ahead, check that the power supply to the Konashi is stable, battery remaining of the iOS device is sufficient, the distance between them is less than 1m without any shields, and no interrupter around you. Bricked Konashi will be recovered by wired firmware update using the Wiced Smart SDK. For more info on this topic, please consult the koshian web site on www.m-pression.com." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
#endif
	[alert show];
}

- (void)connectKonashi:(id)sender
{
	if ([Konashi isConnected]) {
		[Konashi disconnect];
	}
	else {
		[SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
		[Konashi reset];
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
		
		NSData *firmwareData = [[NSData alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:self.firmwareFilename ofType:@"bin"]];
		[[Konashi shared] ota_updateFirmware:firmwareData];
	}
}

@end
