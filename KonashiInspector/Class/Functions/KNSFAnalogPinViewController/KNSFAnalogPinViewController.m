//
//  KNSFAnalogPinViewController.m
//  KonashiInspector
//
//  Created by Akira Matsuda on 11/19/14.
//  Copyright (c) 2014 Akira Matsuda. All rights reserved.
//

#import "KNSFAnalogPinViewController.h"
#import "Konashi.h"

@interface KNSFAnalogPinViewController ()
{
	IBOutletCollection(UILabel) NSArray *outputLabel;
	IBOutletCollection(UILabel) NSArray *inputLabel;
	
}
@end

@implementation KNSFAnalogPinViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	[[Konashi shared] setAnalogPinDidChangeValueHandler:^(KonashiAnalogIOPin pin, int value) {
		UILabel *label = inputLabel[pin];
		label.text = [NSString stringWithFormat:@"%4.3lf", (CGFloat)value / 1000];
	}];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 60;
}

#pragma mark -

- (IBAction)analogPin0ValueChanged:(id)sender
{
	UISlider *slider = sender;
	int value = (int)(slider.value * [[Konashi shared].activePeripheral analogReference]);
	[self updateAnalogOutput:KonashiAnalogIO0 value:value];
}

- (IBAction)analogPin1ValueChanged:(id)sender
{
	UISlider *slider = sender;
	int value = (int)(slider.value * [[Konashi shared].activePeripheral analogReference]);
	[self updateAnalogOutput:KonashiAnalogIO1 value:value];
}

- (IBAction)analogPin2ValueChanged:(id)sender
{
	UISlider *slider = sender;
	CGFloat value = slider.value * [[Konashi shared].activePeripheral analogReference];
	[self updateAnalogOutput:KonashiAnalogIO2 value:value];
}

- (void)updateAnalogOutput:(KonashiAnalogIOPin)pin value:(CGFloat)voltage
{
	[Konashi analogWrite:pin milliVolt:voltage / 1000];
	[(UILabel *)outputLabel[pin] setText:[NSString stringWithFormat:@"%4.3lf", voltage / 1000]];
}

- (IBAction)readAnalogValue0:(id)sender
{
	[Konashi analogReadRequest:KonashiAnalogIO0];
}

- (IBAction)readAnalogValue1:(id)sender
{
	[Konashi analogReadRequest:KonashiAnalogIO1];
}

- (IBAction)readAnalogValue2:(id)sender
{
	[Konashi analogReadRequest:KonashiAnalogIO2];
}

@end
