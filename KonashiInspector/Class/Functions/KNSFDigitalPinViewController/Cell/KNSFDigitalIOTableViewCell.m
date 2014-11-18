//
//  KNSFDigitalIOTableViewCell.m
//  KonashiInspector
//
//  Created by Akira Matsuda on 11/19/14.
//  Copyright (c) 2014 Akira Matsuda. All rights reserved.
//

#import "KNSFDigitalIOTableViewCell.h"
#import "Konashi.h"

@interface KNSFDigitalIOTableViewCell ()
{
	KonashiLevel currentLevel_;
}

@end

@implementation KNSFDigitalIOTableViewCell

- (void)awakeFromNib
{
    // Initialization code
	currentLevel_ = KonashiLevelLow;
	self.outputSegmentedControl.enabled = NO;
	self.toggleButton.enabled = NO;
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventDisconnectedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[self.pinModeSwitch setOn:NO animated:YES];
		self.outputSegmentedControl.enabled = NO;
		self.toggleButton.enabled = NO;
	}];
	
	__weak typeof(self) bself = self;
	[[NSNotificationCenter defaultCenter] addObserverForName:KNSFDigitalPinValueChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		KonashiDigitalIOPin pin = (KonashiDigitalIOPin)[note.userInfo[@"pin"] integerValue];
		if (bself.tag == pin) {
			KonashiLevel level = [Konashi digitalRead:(KonashiDigitalIOPin)bself.tag];
			bself.outputSegmentedControl.selectedSegmentIndex = level == KonashiLevelHigh ? 1 : 0;
		}
	}];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (IBAction)outputSegmentedControlValueChanged:(id)sender
{
	UISegmentedControl *segmentedControl = sender;
	KonashiLevel level = segmentedControl.selectedSegmentIndex == 0 ? KonashiLevelLow : KonashiLevelHigh;
	currentLevel_ = level;
	[Konashi digitalWrite:(KonashiDigitalIOPin)self.tag value:level];
}

- (IBAction)toggleButtonTouchDown:(id)sender
{
	KonashiLevel level = currentLevel_ == KonashiLevelHigh ? KonashiLevelLow : KonashiLevelHigh;
	[self setDigitalIOLevel:level];
}

- (IBAction)toggleButtonTouchUpInside:(id)sender
{
	[self setDigitalIOLevel:currentLevel_];
}

- (IBAction)pinModeSwitchValueChanged:(id)sender
{
	if ([Konashi isConnected]) {
		UISwitch *sw = sender;
		self.outputSegmentedControl.enabled = sw.on;
		self.toggleButton.enabled = sw.on;
		[Konashi pinMode:(KonashiDigitalIOPin)self.tag mode:sw.on == YES ? KonashiPinModeOutput : KonashiPinModeInput];
	}
}

- (void)setDigitalIOLevel:(KonashiLevel)level
{
	[Konashi digitalWrite:(KonashiDigitalIOPin)self.tag value:level];
	self.outputSegmentedControl.selectedSegmentIndex = level == KonashiLevelHigh ? 1 : 0;
}

@end
