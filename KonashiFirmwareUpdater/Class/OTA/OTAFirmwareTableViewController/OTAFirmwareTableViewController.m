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
	NSArray *serverContents;
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
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return section == 0 ? [contents count] : [serverContents count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *const reuseIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier];
	}
	
	if (indexPath.section == 0) {
		cell.textLabel.text = contents[indexPath.row];
	}
	else if (indexPath.section == 1) {
		cell.textLabel.text = serverContents[indexPath.row][@"title"];
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == 0) {
		[[NSNotificationCenter defaultCenter] postNotificationName:OTAFirmwareSelectedNotification object:nil userInfo:@{@"filename":contents[indexPath.row], @"data":[[NSData alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:contents[indexPath.row] ofType:@"bin"]]}];
		[self dismissViewControllerAnimated:YES completion:^{
		}];
	}
	else {
		[SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
		[NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:serverContents[indexPath.row][@"url"]]] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
			if (connectionError == nil) {
				dispatch_async(dispatch_get_main_queue(), ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:OTAFirmwareSelectedNotification object:nil userInfo:@{@"filename":serverContents[indexPath.row][@"title"],@"data":data}];
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

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return section == 0 ? @"Device" : @"Server";
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
	__weak typeof(self) bself = self;
	[NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://konashi.ux-xu.com/api/firmwares/list.json"]] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
		if (connectionError == nil) {
			dispatch_async(dispatch_get_main_queue(), ^{
				NSError *e = nil;
				serverContents = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&e];
				[bself.tableView reloadData];
			});
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			[SVProgressHUD dismiss];
			[bself.tableView reloadData];
			[bself.refreshControl endRefreshing];
		});
	}];
	[self.refreshControl endRefreshing];
}

- (void)dismiss
{
	[self dismissViewControllerAnimated:YES completion:^{
	}];
}

@end
