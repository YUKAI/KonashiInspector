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
    NSArray *iTunesContents;
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
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return section == 0 ? [contents count] : section == 1 ? [iTunesContents count] : [serverContents count];
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
    else if(indexPath.section == 1){
        cell.textLabel.text = iTunesContents[indexPath.row];
    }
	else if (indexPath.section == 2) {
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
    }else if(indexPath.section == 1){
        NSArray *documentDirectries = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentDirectory = [documentDirectries lastObject];
        NSString *filename = iTunesContents[indexPath.row];
        NSLog(@"%@ %@", filename,[NSString stringWithFormat:@"%@/%@",documentDirectory,iTunesContents[indexPath.row]]);
        if([filename hasSuffix:@".bin"]){
            [[NSNotificationCenter defaultCenter] postNotificationName:OTAFirmwareSelectedNotification object:nil userInfo:@{@"filename":filename, @"data":[[NSData alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@",documentDirectory,iTunesContents[indexPath.row]]]}];
        }else if([filename hasSuffix:@".ebl"]){
            [[NSNotificationCenter defaultCenter] postNotificationName:OTAFirmwareSelectedNotification object:nil userInfo:@{@"filename":filename, @"data":[[NSData alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@",documentDirectory,iTunesContents[indexPath.row]]]}];
        }else if([filename hasSuffix:@".gbl"]){
            [[NSNotificationCenter defaultCenter] postNotificationName:OTAFirmwareSelectedNotification object:nil userInfo:@{@"filename":filename, @"data":[[NSData alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@",documentDirectory,iTunesContents[indexPath.row]]]}];
        }else{
            [[NSNotificationCenter defaultCenter] postNotificationName:OTAFirmwareSelectedNotification object:nil userInfo:@{@"filename":filename,@"at":@"iTunes"}];
        }
        [self dismissViewControllerAnimated:YES completion:^{
        }];
    }
	else {
		[SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
		[NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:serverContents[indexPath.row][@"url"]] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:(NSTimeInterval)60.0]
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
			if (connectionError == nil) {
				dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *filename = serverContents[indexPath.row][@"title"];
                    if([filename hasSuffix:@".bin"]){
                        [[NSNotificationCenter defaultCenter] postNotificationName:OTAFirmwareSelectedNotification object:nil userInfo:@{@"filename":filename, @"data":data}];
                    }else if([filename hasSuffix:@".ebl"]){
                        [[NSNotificationCenter defaultCenter] postNotificationName:OTAFirmwareSelectedNotification object:nil userInfo:@{@"filename":filename, @"data":data}];
                    }else if([filename hasSuffix:@".gbl"]){
                        [[NSNotificationCenter defaultCenter] postNotificationName:OTAFirmwareSelectedNotification object:nil userInfo:@{@"filename":filename, @"data":data}];
                    }else{
                        [[NSNotificationCenter defaultCenter] postNotificationName:OTAFirmwareSelectedNotification object:nil userInfo:@{@"filename":filename,@"at":@"server",@"app_url":serverContents[indexPath.row][@"app_url"],@"stack_url":serverContents[indexPath.row][@"stack_url"]}];
                    }
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
    return section == 0 ? @"Device" : section == 1 ? @"iTunes" : @"Server";
}

#pragma mark -

- (void)fetchData
{
	[SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
	NSMutableArray *array = [[NSMutableArray alloc] init];
	NSFileManager* fileManager = [[NSFileManager alloc] init];
	for(NSString *content in [fileManager contentsOfDirectoryAtPath:[[NSBundle mainBundle] bundlePath] error:nil]) {
		if ([content hasSuffix:@"bin"] || [content hasSuffix:@".gbl"] || [content hasSuffix:@".ebl"]) {
			NSString *filename = [content stringByDeletingPathExtension];
			[array addObject:filename];
		}
	}
	contents = [array copy];
    
    NSMutableArray *iTunesArray = [[NSMutableArray alloc] init];
    NSArray *documentDirectries = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [documentDirectries lastObject];
    // ドキュメントディレクトリにあるファイルリスト
    NSError *error = nil;
    NSFileManager *iTunesFileManager = [NSFileManager defaultManager];
    for (NSString *file in [iTunesFileManager contentsOfDirectoryAtPath:documentDirectory error:&error]) {
        if([file hasSuffix:@".bin"] || [file hasSuffix:@".gbl"] || [file hasSuffix:@".ebl"]){
            [iTunesArray addObject:file];
        }else{
            NSString *s = [NSString stringWithFormat:@"%@/%@",documentDirectory,file];
            for(NSString *foldafile in [iTunesFileManager contentsOfDirectoryAtPath:s error:&error]){
                NSLog(@"%@",foldafile);
            }
            [iTunesArray addObject:file];
        }
        
    }
    iTunesContents = [iTunesArray copy];
	__weak typeof(self) bself = self;
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://konashi.ux-xu.com/api/firmwares/list.json"] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:(NSTimeInterval)60.0];
    [NSURLConnection sendAsynchronousRequest: req queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
		if (connectionError == nil) {
			dispatch_async(dispatch_get_main_queue(), ^{
				NSError *e = nil;
				serverContents = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&e];
                NSLog(@"%@",serverContents);
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
