//
//  KNSFCommViewController.m
//  KonashiFirmwareUpdater
//
//  Created by Akira Matsuda on 11/16/14.
//  Copyright (c) 2014 Akira Matsuda. All rights reserved.
//

#import "KNSFCommViewController.h"
#import "AMViralSwitch.h"
#import "Konashi.h"
#import "FontAwesomeKit.h"

@interface KNSFCommViewController ()
{
	KonashiUartBaudrate baudrate_;
	KonashiI2CMode i2cMode_;
	__weak IBOutlet AMViralSwitch *uartEnableSwitch_;
	__weak IBOutlet UILabel *uartBaudrateLabel_;
	__weak IBOutlet UIButton *uartBaudrateChangeButton_;
	__weak IBOutlet UIButton *uartSendButton_;
	__weak IBOutlet UITextField *uartSendStringTextField_;
	__weak IBOutlet UITextView *uartReceivedDataTextView_;
	__weak IBOutlet UILabel *uartLabel_;
	__weak IBOutlet UISwitch *uartSendDataTypeSwitch_;
	
	__weak IBOutlet AMViralSwitch *i2cEnableSwitch_;
	__weak IBOutlet UISegmentedControl *i2cSpeedSegmentedControl_;
	__weak IBOutlet UIButton *i2cSendDataButton_;
	__weak IBOutlet UIButton *i2cReceiveDataButton_;
	__weak IBOutlet UITextView *i2cReceivedDataTextView_;
	__weak IBOutlet UILabel *i2cLabel_;
	
	NSArray *baudrateList_;
	BOOL visible_;
}

@end

@implementation KNSFCommViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.title = @"Comm";
	baudrateList_ = @[@"2400", @"9600", @"19200", @"38400", @"57600", @"76800", @"115200"];
	uartBaudrateLabel_.text = @"9600";
	baudrate_ = KonashiUartBaudrateRate9K6;
	uartSendStringTextField_.delegate = self;
	uartBaudrateChangeButton_.layer.borderColor = uartBaudrateChangeButton_.tintColor.CGColor;
	uartBaudrateChangeButton_.layer.borderWidth = 1;
	uartBaudrateChangeButton_.layer.cornerRadius = 13;
	uartSendButton_.layer.borderColor = uartBaudrateChangeButton_.tintColor.CGColor;
	uartSendButton_.layer.borderWidth = 1;
	uartSendButton_.layer.cornerRadius = 15;
	
	i2cMode_ = KonashiI2CModeEnable100K;
	i2cSendDataButton_.layer.borderWidth = 1;
	i2cSendDataButton_.layer.borderColor = i2cSendDataButton_.tintColor.CGColor;
	i2cSendDataButton_.layer.cornerRadius = 15;
	i2cReceiveDataButton_.layer.borderWidth = 1;
	i2cReceiveDataButton_.layer.borderColor = i2cReceiveDataButton_.tintColor.CGColor;
	i2cReceiveDataButton_.layer.cornerRadius = 15;
	
	[self updateControlState];
	
	[Konashi shared].connectedHandler = ^() {
		[self updateControlState];
	};
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventDisconnectedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		BOOL previousState = uartEnableSwitch_.on;
		[uartEnableSwitch_ setOn:NO animated:YES];
		if (previousState == YES) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
			[uartEnableSwitch_ performSelector:@selector(switchChanged:) withObject:uartEnableSwitch_];
#pragma clang diagnostic pop
		}
		previousState = i2cEnableSwitch_.on;
		[i2cEnableSwitch_ setOn:NO animated:YES];
		if (previousState == YES) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
			[i2cEnableSwitch_ performSelector:@selector(switchChanged:) withObject:i2cEnableSwitch_];
#pragma clang diagnostic pop
		}
		[self i2cEnableSwitchValueChanged:i2cEnableSwitch_];
		
		[self updateControlState];
	}];
	
	[[Konashi shared] setUartRxCompleteHandler:^(NSData *data) {
		NSString *string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
		NSString *text = [uartReceivedDataTextView_.text stringByAppendingString:string];
		uartReceivedDataTextView_.text = text;
//		NSLog(@"uart RX complete:%@(%@:length = %ld)", string, [data description], (unsigned long)data.length);
		NSLog(@"%@", text);
	}];
	[[Konashi shared] setI2cReadCompleteHandler:^(NSData *data) {
		NSLog(@"i2c read complete:(%@:length = %ld)", [data description], (unsigned long)data.length);
		unsigned char d[[[[Konashi shared].activePeripheral.impl class] i2cDataMaxLength]];
		[[Konashi i2cReadData] getBytes:d];
		[NSThread sleepForTimeInterval:0.01];
		[Konashi i2cStopCondition];
		NSMutableString *string = [NSMutableString new];
		for (NSInteger i = 0; i < [[[Konashi shared].activePeripheral.impl class] i2cDataMaxLength]; i++) {
			[string appendString:[NSString stringWithFormat:@"%d", d[i]]];
		}
		i2cReceivedDataTextView_.text = [i2cReceivedDataTextView_.text stringByAppendingString:string];
	}];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		uartEnableSwitch_.animationElementsOn = @[
												  @{ AMElementView: uartBaudrateLabel_,
													 AMElementKeyPath: @"textColor",
													 AMElementToValue: [UIColor whiteColor] },
												  @{ AMElementView: uartLabel_,
													 AMElementKeyPath: @"textColor",
													 AMElementToValue: [UIColor whiteColor] },
												  @{ AMElementView: uartBaudrateChangeButton_,
													 AMElementKeyPath: @"tintColor",
													 AMElementToValue: [UIColor whiteColor]},
												  @{ AMElementView: uartBaudrateChangeButton_.layer,
													 AMElementKeyPath: @"borderColor",
													 AMElementToValue: (id)[UIColor whiteColor].CGColor},
												  ];
		uartEnableSwitch_.animationElementsOff = @[
												   @{ AMElementView: uartBaudrateLabel_,
													  AMElementKeyPath: @"textColor",
													  AMElementToValue: [UIColor blackColor] },
												   @{ AMElementView: uartLabel_,
													  AMElementKeyPath: @"textColor",
													  AMElementToValue: [UIColor blackColor] },
												   @{ AMElementView: uartBaudrateChangeButton_,
													  AMElementKeyPath: @"tintColor",
													  AMElementToValue: uartBaudrateChangeButton_.tintColor},
												   @{ AMElementView: uartBaudrateChangeButton_.layer,
													  AMElementKeyPath: @"borderColor",
													  AMElementToValue: (id)BaseViewDefaultBackgroundColor.CGColor},
												   ];
		
		i2cEnableSwitch_.animationElementsOn = @[
												  @{ AMElementView: i2cLabel_,
													 AMElementKeyPath: @"textColor",
													 AMElementToValue: [UIColor whiteColor] },
												  ];
		i2cEnableSwitch_.animationElementsOff = @[
												   @{ AMElementView: i2cLabel_,
													  AMElementKeyPath: @"textColor",
													  AMElementToValue: [UIColor blackColor] },
												   ];
	});
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	visible_ = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	visible_ = NO;
}

#pragma mark -
#pragma mark - UART

- (IBAction)uartSendString:(id)sender
{
	if (uartSendDataTypeSwitch_.on == YES) {
		NSMutableData *data = [NSMutableData new];
		NSArray *byteStrings = [uartSendStringTextField_.text componentsSeparatedByString:@" "];
		[byteStrings enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			NSString *str = obj;
			NSInteger i = [str integerValue];
			[data appendBytes:&i length:1];
		}];
		NSLog(@"uart byte send :%@", [data description]);
		[Konashi uartWriteData:data];
	}
	else {
		[Konashi uartWriteString:uartSendStringTextField_.text];
		NSLog(@"uart string send :%@", uartSendStringTextField_.text);
	}
}


- (IBAction)clearUartTextView:(id)sender
{
	uartReceivedDataTextView_.text = @"";
}

- (IBAction)uartEnableSwitchValueChanged:(id)sender
{
	UISwitch *sw = sender;
	if (sw.on) {
		[Konashi uartMode:KonashiUartModeEnable baudrate:baudrate_];
	}
	else {
		[Konashi uartMode:KonashiUartModeDisable baudrate:baudrate_];
	}
	
	uartBaudrateChangeButton_.enabled = !sw.on;
	uartSendButton_.enabled = sw.on;
}

- (IBAction)uartBaudrateChangeButtonChanged:(id)sender
{
	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Select baudrate" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:nil];
	for (NSString *title in baudrateList_) {
		[actionSheet addButtonWithTitle:title];
	}
	[actionSheet setCancelButtonIndex:0];
	[actionSheet showInView:self.view];
}

- (IBAction)uartChangeSendDataType:(id)sender
{
	UISwitch *sw = sender;
	uartSendStringTextField_.placeholder = sw.on == YES ? @"as byte" : @"as string";
}

#pragma mark - I2C

- (IBAction)i2cSendData:(id)sender
{
	NSLog(@"i2cSendData");
	unsigned char t[[[[Konashi shared].activePeripheral.impl class] i2cDataMaxLength]];
	for(NSInteger i = 0; i < (int)[[[Konashi shared].activePeripheral.impl class] i2cDataMaxLength]; i++){
		t[i] = 'A' + i;
	}
	
	[Konashi i2cStartCondition];
	[NSThread sleepForTimeInterval:0.01];
	[Konashi i2cWriteData:[NSData dataWithBytes:t length:(int)[[[Konashi shared].activePeripheral.impl class] i2cDataMaxLength]] address:0x1F];
	[NSThread sleepForTimeInterval:0.01];
	[Konashi i2cStopCondition];
	[NSThread sleepForTimeInterval:0.01];
}

- (IBAction)i2cReceiveData:(id)sender
{
	NSLog(@"i2cReceiveData");
	[Konashi i2cStartCondition];
	[NSThread sleepForTimeInterval:0.01];
	[Konashi i2cReadRequest:(int)[[[Konashi shared].activePeripheral.impl class] i2cDataMaxLength] address:0x1F];
}

- (IBAction)clearI2CTextView:(id)sender
{
	i2cReceivedDataTextView_.text = @"";
}

- (IBAction)i2cEnableSwitchValueChanged:(id)sender
{
	UISwitch *sw = sender;
	UIColor *color = [UIColor whiteColor];
	if (sw.on) {
		if (i2cSpeedSegmentedControl_.selectedSegmentIndex == 1) {
			i2cMode_ = KonashiI2CModeEnable400K;
		}
		else {
			i2cMode_ = KonashiI2CModeEnable100K;
		}
	}
	else {
		color = BaseViewDefaultBackgroundColor;
		i2cMode_ = KonashiI2CModeDisable;
	}
	
	[UIView animateWithDuration:0.35 animations:^{
		i2cSpeedSegmentedControl_.tintColor = color;
	}];
	
	[Konashi i2cMode:i2cMode_];
	[self updateControlState];
}
- (IBAction)i2cSpeedSegmentedControlIndexChanged:(id)sender
{
	UISegmentedControl *segmentedControl = sender;
	if (segmentedControl.selectedSegmentIndex == 1) {
		i2cMode_ = KonashiI2CModeEnable400K;
	}
	else {
		i2cMode_ = KonashiI2CModeEnable100K;
	}
	NSLog(@"set i2c mode:%d", i2cMode_);
	[Konashi i2cMode:i2cMode_];
}

- (void)updateControlState
{
	uartEnableSwitch_.enabled = [Konashi isConnected];
	i2cEnableSwitch_.enabled = [Konashi isConnected];
	
	uartSendButton_.enabled = uartEnableSwitch_.on;
	uartBaudrateChangeButton_.enabled = !uartEnableSwitch_.on;
	i2cSpeedSegmentedControl_.enabled = !i2cEnableSwitch_.on;
	i2cSendDataButton_.enabled = i2cEnableSwitch_.on;
	i2cReceiveDataButton_.enabled = i2cEnableSwitch_.on;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex > 0) {
		baudrate_ = (KonashiUartBaudrate)([baudrateList_[buttonIndex - 1] integerValue] / 240);
		uartBaudrateLabel_.text = baudrateList_[buttonIndex - 1];
		NSLog(@"set baudrate:%d", baudrate_);
	}
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	return YES;
}

@end
