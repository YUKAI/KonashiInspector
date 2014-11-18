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

@implementation KNSFDigitalPinViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	[self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([KNSFDigitalIOTableViewCell class]) bundle:nil] forCellReuseIdentifier:@"Cell"];
	[[Konashi shared] setDigitalInputDidChangeValueHandler:^(KonashiDigitalIOPin pin, int value) {
		[[NSNotificationCenter defaultCenter] postNotificationName:KNSFDigitalPinValueChangedNotification object:nil userInfo:@{@"pin":@(pin)}];
	}];
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
	cell.tag = indexPath.row;
	cell.pinNumberLabel.text = [NSString stringWithFormat:@"%ld", indexPath.row];
	
	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 54;
}

@end
