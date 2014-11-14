//
//  OTAImageTableViewController.m
//  KonashiJs
//
//  Created by Akira Matsuda on 11/5/14.
//  Copyright (c) 2014 Yukai Engineering. All rights reserved.
//

#import "OTAFirmwareTableViewController.h"
#import "SVProgressHUD.h"

@interface OTAFirmwareTableViewController ()
{
	NSArray *contents;
}

@end

@implementation OTAFirmwareTableViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.title = @"Firmware list";
	UIBarButtonItem *dismissButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismiss)];
	self.navigationItem.rightBarButtonItem = dismissButton;
	
	self.refreshControl = [[UIRefreshControl alloc] init];
	[self.refreshControl addTarget:self action:@selector(fetchData) forControlEvents:UIControlEventValueChanged];
	
	[self fetchData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [contents count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *const reuseIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
	}
	
	cell.textLabel.text = contents[indexPath.row];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[[NSNotificationCenter defaultCenter] postNotificationName:OTAFirmwareSelectedNotification object:contents[indexPath.row]];
	[self dismissViewControllerAnimated:YES completion:^{
	}];
}

#pragma mark -

- (void)fetchData
{
	[SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
	NSMutableArray *array = [[NSMutableArray alloc] init];
	NSFileManager* fileManager = [[NSFileManager alloc] init];
	for(NSString *content in [fileManager contentsOfDirectoryAtPath:[[NSBundle mainBundle] bundlePath] error:nil]) {
		if ([content hasSuffix:@"bin"]) {
			NSString *filename = [content stringByDeletingPathExtension];
			[array addObject:filename];
		}
	}
	contents = [array copy];
	[self.tableView reloadData];
	[SVProgressHUD dismiss];
	[self.refreshControl endRefreshing];
}

- (void)dismiss
{
	[self dismissViewControllerAnimated:YES completion:^{
	}];
}

@end
