//
//  KNSFDigitalPinViewController.m
//  KonashiInspector
//
//  Created by Akira Matsuda on 11/19/14.
//  Copyright (c) 2014 Akira Matsuda. All rights reserved.
//

#import "KNSFDigitalPinViewController.h"
#import "KNSFDigitalIOTableViewCell.h"
#import "Konashi.h"

@interface KNSFDigitalPinViewController () <SWTableViewCellDelegate>

@property (nonatomic, assign) NSUInteger pullupState;

@end

@implementation KNSFDigitalPinViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	[self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([KNSFDigitalIOTableViewCell class]) bundle:nil] forCellReuseIdentifier:@"Cell"];
	self.tableView.clipsToBounds = YES;
	[[Konashi shared] setDigitalInputDidChangeValueHandler:^(KonashiDigitalIOPin pin, int value) {
		[[NSNotificationCenter defaultCenter] postNotificationName:KNSFDigitalPinValueChangedNotification object:nil userInfo:@{@"pin":@(pin)}];
	}];
	self.pullupState = 0;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	// Return the number of sections.
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	// Return the number of rows in the section.
	return 8;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *CellIdentifier = @"Cell";
	KNSFDigitalIOTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	button.backgroundColor = self.pullupState & cell.tag ? [UIColor colorWithRed:1.0f green:0.1491f blue:0.0f alpha:1.0] : [UIColor colorWithRed:0.0f green:0.5695f blue:1.0f alpha:1.0];
	[button setTitle:self.pullupState & cell.tag ? @"NoPulls" : @"Pullup" forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[button.titleLabel setAdjustsFontSizeToFitWidth:YES];
	cell.rightUtilityButtons = @[button];
	
	cell.tag = indexPath.row;
	cell.pinNumberLabel.text = [NSString stringWithFormat:@"%ld", (long)indexPath.row];
	cell.delegate = self;
	
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 54;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

#pragma mark - UITableViewDelegate

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - 

- (void)swipeableTableViewCell:(SWTableViewCell *)cell didTriggerRightUtilityButtonWithIndex:(NSInteger)index
{
	switch (index) {
		case 0:
			if (self.pullupState & cell.tag) {
				[Konashi pinPullup:cell.tag mode:KonashiPinModeNoPulls];
			}
			else {
				[Konashi pinPullup:cell.tag mode:KonashiPinModePullup];
			}
			self.pullupState ^= cell.tag;

			[UIView animateWithDuration:0.5 animations:^{
				((KNSFDigitalIOTableViewCell *)cell).pullupIndicatorLabel.alpha = self.pullupState & cell.tag;
			} completion:^(BOOL finished) {
				UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
				button.backgroundColor = self.pullupState & cell.tag ? [UIColor colorWithRed:1.0f green:0.1491f blue:0.0f alpha:1.0] : [UIColor colorWithRed:0.0f green:0.5695f blue:1.0f alpha:1.0];
				[button setTitle:self.pullupState & cell.tag ? @"NoPulls" : @"Pullup" forState:UIControlStateNormal];
				[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
				[button.titleLabel setAdjustsFontSizeToFitWidth:YES];
				cell.rightUtilityButtons = @[button];
			}];

			break;
	}
	[cell hideUtilityButtonsAnimated:YES];
}

@end
