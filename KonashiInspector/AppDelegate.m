//
//  AppDelegate.m
//  KonashiFirmwareUpdater
//
//  Created by Akira Matsuda on 11/14/14.
//  Copyright (c) 2014 Akira Matsuda. All rights reserved.
//

#import "AppDelegate.h"
#import "JDStatusBarNotification.h"
#import "Konashi.h"
#import "FontAwesomeKit.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// Override point for customization after application launch.
	NSString *KonashiReadyToUseStyle = @"KonashiReadyToUseStyle";
	[JDStatusBarNotification addStyleNamed:KonashiReadyToUseStyle prepare:^JDStatusBarStyle*(JDStatusBarStyle *style) {
									   style.barColor = [UIColor colorWithRed:0.000 green:0.478 blue:1.000 alpha:1.000];
									   style.textColor = [UIColor whiteColor];
									   return style;
								   }];
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventReadyToUseNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[JDStatusBarNotification showWithStatus:[NSString stringWithFormat:@"Connected:%@", [Konashi shared].activePeripheral.peripheral.name] styleName:KonashiReadyToUseStyle];
		for (NSInteger i = 0; i < 8; i++) {
			[Konashi pinMode:(KonashiDigitalIOPin)i mode:KonashiPinModeInput];
		}
	}];
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventDisconnectedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[JDStatusBarNotification dismiss];
	}];
	
	UITabBarController *tabBarController = (UITabBarController *)self.window.rootViewController;
	[tabBarController.tabBar.items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		UITabBarItem *item = obj;
		UIImage *image = nil;
		if (idx == 0) {
			// Device info
			image = [[FAKFontAwesome infoIconWithSize:20] imageWithSize:CGSizeMake(25, 25)];
		}
		else if (idx == 1) {
			// OTA Update
			image = [[FAKFontAwesome wifiIconWithSize:20] imageWithSize:CGSizeMake(25, 25)];
		}
		else if	(idx == 2) {
			// PIO
			image = [[FAKFontAwesome dotCircleOIconWithSize:20] imageWithSize:CGSizeMake(25, 25)];
		}
		else if (idx == 3) {
			// AIO
			image = [[FAKFontAwesome bullseyeIconWithSize:20] imageWithSize:CGSizeMake(25, 25)];
		}
		else if (idx == 4) {
			// Command
			image = [[FAKFontAwesome terminalIconWithSize:20] imageWithSize:CGSizeMake(25, 25)];
		}
		[item setImage:image];
	}];
	
	return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
