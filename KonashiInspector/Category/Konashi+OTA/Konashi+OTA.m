//
//  Konashi+OTA.m
//  KonashiJs
//
//  Created by Akira Matsuda on 11/5/14.
//  Copyright (c) 2014 Yukai Engineering. All rights reserved.
//

#import "Konashi+OTA.h"
#import <zlib.h>
#import "CBService+Konashi.h"
#import <objc/runtime.h>
#import "KNSKonashiPeripheralImpl.h"
#import "KNSKoshianPeripheralImpl.h"

@implementation KNSPeripheralBaseImpl (OTA)

- (void)writeData:(NSData *)data serviceUUID:(CBUUID*)serviceUUID characteristicUUID:(CBUUID*)characteristicUUID type:(CBCharacteristicWriteType)type
{
	CBService *service = [self.peripheral kns_findServiceFromUUID:serviceUUID];
	if (!service) {
		KNS_LOG(@"Could not find service with UUID %@ on peripheral with UUID %@", [serviceUUID kns_dataDescription], self.peripheral.identifier.UUIDString);
		[[NSNotificationCenter defaultCenter] postNotificationName:KONASHI_OTA_ERROR_NOTIFICATION object:[NSError errorWithDomain:[NSString stringWithFormat:@"Could not find service with UUID %@ on peripheral with UUID %@", [serviceUUID kns_dataDescription], self.peripheral.identifier.UUIDString] code:100 userInfo:nil]];
		return;
	}
	CBCharacteristic *characteristic = [service kns_findCharacteristicFromUUID:characteristicUUID];
	if (!characteristic) {
		KNS_LOG(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@", [characteristicUUID kns_dataDescription], [serviceUUID kns_dataDescription], self.peripheral.identifier.UUIDString);
		[[NSNotificationCenter defaultCenter] postNotificationName:KONASHI_OTA_ERROR_NOTIFICATION object:[NSError errorWithDomain:[NSString stringWithFormat:@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@", [characteristicUUID kns_dataDescription], [serviceUUID kns_dataDescription], self.peripheral.identifier.UUIDString] code:101 userInfo:nil]];
		return;
	}
	[self.peripheral writeValue:data forCharacteristic:characteristic type:type];
}

@end

@implementation KNSKonashiPeripheralImpl (OTA)

- (void)writeData:(NSData *)data serviceUUID:(CBUUID*)serviceUUID characteristicUUID:(CBUUID*)characteristicUUID type:(CBCharacteristicWriteType)type
{
	CBService *service = [self.peripheral kns_findServiceFromUUID:serviceUUID];
	if (!service) {
		KNS_LOG(@"Could not find service with UUID %@ on peripheral with UUID %@", [serviceUUID kns_dataDescription], self.peripheral.identifier.UUIDString);
		return;
	}
	CBCharacteristic *characteristic = [service kns_findCharacteristicFromUUID:characteristicUUID];
	if (!characteristic) {
		KNS_LOG(@"Could not find characteristic with UUID %@ on service with UUID %@ on peripheral with UUID %@", [characteristicUUID kns_dataDescription], [serviceUUID kns_dataDescription], self.peripheral.identifier.UUIDString);
		return;
	}
	[self.peripheral writeValue:data forCharacteristic:characteristic type:type];
	[NSThread sleepForTimeInterval:0.03];
}

@end

@implementation KNSPeripheral (OTA)

- (void)writeData:(NSData *)data serviceUUID:(CBUUID *)uuid characteristicUUID:(CBUUID *)charasteristicUUID type:(CBCharacteristicWriteType)type
{
	[self.impl writeData:data serviceUUID:uuid characteristicUUID:charasteristicUUID type:type];
}

@end

@implementation Konashi (OTA)

typedef struct __attribute__((packed))
{
	uint8_t opcode;
	union
	{
		uint16_t n_packets;
		struct __attribute__((packed))
		{
			uint8_t   original;
			uint8_t   response;
		};
		uint32_t n_bytes;
	};
} dfu_control_point_data_t;

typedef enum
{
	PREPARE_DOWNLOAD = 1,
	DOWNLOAD = 2,
	VALIDATE_FIRMWARE = 3,
	ABORT = 7,
	INITIALIZE_DFU_PARAMS,
	RECEIVE_FIRMWARE_IMAGE,
	ACTIVATE_RESET,
	RESET,
	REPORT_SIZE,
	REQUEST_RECEIPT,
	RESPONSE_CODE = 0x10,
	RECEIPT,
} DFUTargetOpcode;

static NSString *ota_stepCount = @"ota_stepCount";
static NSString *ota_firmwareData = @"ota_firmwareData";
static NSString *ota_progressBlock = @"ota_progressBlock";

- (NSInteger)ota_stepCount
{
	return [(NSNumber *)objc_getAssociatedObject(self, (__bridge const void *)(ota_stepCount)) integerValue];
}

- (void)setOta_stepCount:(NSInteger)count
{
	objc_setAssociatedObject(self, (__bridge const void *)(ota_stepCount), @(count), OBJC_ASSOCIATION_RETAIN);
}

- (NSData *)ota_firmwareData
{
	return objc_getAssociatedObject(self, (__bridge const void *)(ota_firmwareData));
}

- (void)setOta_firmwareData:(NSData *)data
{
	objc_setAssociatedObject(self, (__bridge const void *)(ota_firmwareData), data, OBJC_ASSOCIATION_RETAIN);
}

- (CBCharacteristic *)ota_controlPointCharacteristic
{
	static CBCharacteristic *c = nil;
	if (c == nil) {
		BOOL stop = NO;
		for (CBService *service in self.activePeripheral.peripheral.services) {
			KNSKoshianPeripheralImpl *impl = (KNSKoshianPeripheralImpl *)[Konashi shared].activePeripheral.impl;
			CBCharacteristic *characteristic = [service kns_findCharacteristicFromUUID:[[impl class] upgradeCharacteristicControlPointUUID]];
			if (characteristic != nil) {
				c = characteristic;
				stop = YES;
			}
		}
	}
	
	return c;
}

- (void (^)(CGFloat, NSString *))ota_progressBlock
{
	return objc_getAssociatedObject(self, (__bridge const void *)(ota_progressBlock));
}

- (void)setOta_progressBlock:(void (^)(CGFloat progress, NSString *status))block
{
	objc_setAssociatedObject(self, (__bridge const void *)(ota_progressBlock), block, OBJC_ASSOCIATION_RETAIN);
}

#pragma mark -

BOOL interupted;
static NSOperationQueue *q;
- (void)ota_updateFirmware:(NSData *)data
{
	KNSKoshianPeripheralImpl *impl = (KNSKoshianPeripheralImpl *)[Konashi shared].activePeripheral.impl;
	[[Konashi shared].activePeripheral notificationWithServiceUUID:[[impl class] upgradeServiceUUID] characteristicUUID:[[impl class] upgradeCharacteristicControlPointUUID] on:YES];
	NSInteger count = [self ota_stepCount];
	count = 0;
	[self setOta_stepCount:count];
	[self setOta_firmwareData:data];
	[self ota_stepOver];
	interupted = NO;
	[[NSNotificationCenter defaultCenter] addObserverForName:KonashiEventDisconnectedNotification object:nil queue:q usingBlock:^(NSNotification *note) {
		interupted = YES;
	}];
}

- (void)ota_stepOver
{
	void (^progressBlock)(CGFloat progress, NSString *status) = [self ota_progressBlock];
	KNSKoshianPeripheralImpl *impl = (KNSKoshianPeripheralImpl *)[Konashi shared].activePeripheral.impl;
	NSInteger count = [self ota_stepCount];
	switch (count) {
		case 0: {
			if (progressBlock) {
				progressBlock(-1, @"Preparing...");
			}

			dfu_control_point_data_t data;
			data.opcode = PREPARE_DOWNLOAD;
			NSData *commandData = [NSData dataWithBytes:&data length:1];
			[[Konashi shared].activePeripheral writeData:commandData serviceUUID:[[impl class] upgradeServiceUUID] characteristicUUID:[[impl class] upgradeCharacteristicControlPointUUID] type:CBCharacteristicWriteWithResponse];
		}
			break;
		case 1: {
			if (progressBlock) {
				progressBlock(-1, @"Uploading...");
			}
			
			dfu_control_point_data_t data;
			data.opcode = DOWNLOAD;
			data.n_packets = [self ota_firmwareData].length;
			NSData *commandData = [NSData dataWithBytes:&data length:3];
			[[Konashi shared].activePeripheral writeData:commandData serviceUUID:[[impl class] upgradeServiceUUID] characteristicUUID:[[impl class] upgradeCharacteristicControlPointUUID] type:CBCharacteristicWriteWithResponse];
		}
			break;
		case 2: {
			static dispatch_once_t onceToken;
			dispatch_once(&onceToken, ^{
				q = [NSOperationQueue new];
			});
			[q addOperationWithBlock:^{
				NSUInteger DFUCONTROLLER_MAX_PACKET_SIZE = 20;
				NSUInteger sendByteLength = 0;
				NSData *firmwareData = [self ota_firmwareData];
				for (NSInteger i = 0; sendByteLength < firmwareData.length; i++) {
					if (interupted) {
						[[NSNotificationCenter defaultCenter] postNotificationName:KONASHI_OTA_ERROR_NOTIFICATION object:[NSError errorWithDomain:[NSString stringWithFormat:@"iOS was disconnected from device."] code:200 userInfo:nil]];
						return;
					}
					unsigned long length = (firmwareData.length - sendByteLength) > DFUCONTROLLER_MAX_PACKET_SIZE ? DFUCONTROLLER_MAX_PACKET_SIZE : firmwareData.length - sendByteLength;
					NSData *data = [firmwareData subdataWithRange:NSMakeRange(sendByteLength, length)];
					dispatch_async(dispatch_get_main_queue(), ^{
						[[Konashi shared].activePeripheral writeData:data serviceUUID:[[impl class] upgradeServiceUUID] characteristicUUID:[[impl class] upgradeCharacteristicDataUUID] type:CBCharacteristicWriteWithResponse];
					});
					sendByteLength += length;
					if (progressBlock) {
						progressBlock(sendByteLength / (CGFloat)firmwareData.length - 0.01, @"Uploading...");
					}
					[NSThread sleepForTimeInterval:0.05];
				}
				if (progressBlock) {
					progressBlock(-1, @"Validating...");
				}
				dfu_control_point_data_t data;
				data.opcode = VALIDATE_FIRMWARE;
                data.n_bytes = (unsigned int)crc32(0, [firmwareData bytes], (unsigned int)[firmwareData length]);
				NSData *commandData = [NSData dataWithBytes:&data length:5];
				dispatch_async(dispatch_get_main_queue(), ^{
					[[Konashi shared].activePeripheral writeData:commandData serviceUUID:[[impl class] upgradeServiceUUID] characteristicUUID:[[impl class] upgradeCharacteristicControlPointUUID] type:CBCharacteristicWriteWithResponse];
				});
			}];
		}
			break;
		case 3: {
			if (progressBlock) {
				progressBlock(1.0, @"Done");
			}
			[[NSNotificationCenter defaultCenter] postNotificationName:KONASHI_OTA_FINISH_NOTIFICATION object:nil];
		}
		default:
			break;
	}
	count++;
	[self setOta_stepCount:count];
}

@end

@implementation KNSKoshianPeripheralImpl (OTA)

#pragma mark - CoreBluetooth

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
	if ([[characteristic UUID] kns_isEqualToUUID:[[[Konashi shared] ota_controlPointCharacteristic] UUID]]) {
		if (error) {
			[[NSNotificationCenter defaultCenter] postNotificationName:KONASHI_OTA_ERROR_NOTIFICATION object:error];
		}
		else {
			[[Konashi shared] ota_stepOver];
		}
	}
}

@end
