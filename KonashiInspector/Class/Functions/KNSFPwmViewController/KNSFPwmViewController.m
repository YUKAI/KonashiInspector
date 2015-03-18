//
//  KNSFPwmViewController.m
//  KonashiInspector
//
//  Created by Akira Matsuda on 3/18/15.
//  Copyright (c) 2015 Akira Matsuda. All rights reserved.
//

#import "KNSFPwmViewController.h"
#import "Konashi.h"

@interface KNSFPwmState : NSObject

@property (nonatomic, assign) KonashiDigitalIOPin pinNumber;
@property (nonatomic, assign) KonashiPWMMode mode;
@property (nonatomic, assign) unsigned int period;
@property (nonatomic, assign) unsigned int duty;

@end

@implementation KNSFPwmState

@end

@interface KNSFPwmViewController ()

@property (weak, nonatomic) IBOutlet UILabel *selectedPinNumberLabel;
@property (weak, nonatomic) IBOutlet UISwitch *pwmEnabledSwitch;
@property (weak, nonatomic) IBOutlet UITextField *periodTextField;
@property (weak, nonatomic) IBOutlet UISlider *periodSlider;
@property (weak, nonatomic) IBOutlet UITextField *dutyTextField;
@property (weak, nonatomic) IBOutlet UISlider *dutySlider;
@property (weak, nonatomic) IBOutlet UIButton *changePinButton;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, strong) NSMutableArray *pwmState;

@end

@implementation KNSFPwmViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.pwmState = [NSMutableArray new];
	for (NSInteger i = 0; i < 8; i++) {
		KNSFPwmState *state = [KNSFPwmState new];
		state.pinNumber = (KonashiDigitalIOPin)i;
		state.mode = KonashiPWMModeDisable;
		[self.pwmState addObject:state];
	}
	self.changePinButton.layer.cornerRadius = 22;
	self.changePinButton.layer.borderColor = self.changePinButton.tintColor.CGColor;
	self.changePinButton.layer.borderWidth = 1;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if (textField == self.periodTextField) {
		[self updatePeriod:[self.periodTextField.text intValue]];
	}
	else if (textField == self.dutyTextField) {
		[self updateDuty:[self.dutyTextField.text intValue]];
	}
	
	[textField resignFirstResponder];
	return YES;
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex > 0) {
		NSInteger pinNumber = [[actionSheet buttonTitleAtIndex:buttonIndex] integerValue];
		self.selectedIndex = pinNumber;
		NSLog(@"set pin number:%ld", (long)pinNumber);
		KNSFPwmState *state = self.pwmState[pinNumber];
		self.selectedPinNumberLabel.text = [NSString stringWithFormat:@"%ld", (long)pinNumber];
		[self updatePeriod:state.period];
		[self updateDuty:state.duty];
		self.pwmEnabledSwitch.on = state.mode == KonashiPWMModeEnable ? YES : NO;
	}
}

#pragma mark -

- (IBAction)changePwmMode:(id)sender
{
	UISwitch *sw = sender;
	KNSFPwmState *state = self.pwmState[self.selectedIndex];
	state.mode = sw.on == YES ? KonashiPWMModeEnable : KonashiPWMModeDisable;
	[Konashi pwmMode:state.pinNumber mode:state.mode];
}

- (IBAction)changeSelectedPinNumber:(id)sender
{
	UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Change pin number" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:nil];
	for (NSInteger i = 0; i < 8; i++) {
		[actionSheet addButtonWithTitle:[NSString stringWithFormat:@"%ld", (long)i]];
	}
	[actionSheet showInView:self.view];
}

- (IBAction)periodSliderDidValueChange:(id)sender
{
	UISlider *slider = sender;
	[self updatePeriod:10000 * slider.value];
}

- (IBAction)dutySliderDidChangeValue:(id)sender
{
	UISlider *slider = sender;
	[self updateDuty:10000 * slider.value];
}

- (void)updatePeriod:(unsigned int)period
{
	self.periodTextField.text = [NSString stringWithFormat:@"%u", period];
	self.periodSlider.value = period / 10000.0;
	KNSFPwmState *state = self.pwmState[self.selectedIndex];
	state.period = period;
	[Konashi pwmPeriod:state.pinNumber period:state.period];
	[Konashi pwmMode:state.pinNumber mode:state.mode];
}

- (void)updateDuty:(unsigned int)duty
{
	self.dutyTextField.text = [NSString stringWithFormat:@"%u", duty];
	self.dutySlider.value = duty / 10000.0;
	KNSFPwmState *state = self.pwmState[self.selectedIndex];
	state.duty = duty;
	[Konashi pwmDuty:state.pinNumber duty:state.duty];
	[Konashi pwmMode:state.pinNumber mode:state.mode];
}

@end
