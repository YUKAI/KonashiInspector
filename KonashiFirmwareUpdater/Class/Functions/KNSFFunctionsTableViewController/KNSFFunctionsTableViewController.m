//
//  KNSFFunctionsTableViewController.m
//  KonashiFirmwareUpdater
//
//  Created by Akira Matsuda on 11/15/14.
//  Copyright (c) 2014 Akira Matsuda. All rights reserved.
//

#import "KNSFFunctionsTableViewController.h"

@implementation KNSFFunctionsTableViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.title = @"Functions";
	[self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
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
	return 10;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *const CellIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	cell.textLabel.text = @"1";
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	
}

@end
