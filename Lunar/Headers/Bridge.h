//
//  Bridge.h
//  Lunar
//
//  Created by Alin Panaitiu on 08.03.2023.
//  Copyright © 2023 Alin. All rights reserved.
//

#ifndef Bridge_h
#define Bridge_h

@interface SidecarDevice : NSObject <NSSecureCoding>
{
    NSUUID *_identifier;
    NSString *_model;
    NSString *_name;
    unsigned long long _status;
    NSString *_version;
    unsigned long long _generation;
}

+ (id)allDevices;
+ (BOOL)supportsSecureCoding;
@property(readonly, nonatomic) NSURL *imageURL;
@property(readonly, nonatomic) NSString *localizedDeviceType;
@property(readonly, nonatomic) NSString *deviceTypeIdentifier;
@property(nonatomic) unsigned long long status;
@property(readonly, nonatomic) _Bool hasHomeButton;
@property(readonly, nonatomic) NSString *version;
@property(readonly, nonatomic) NSString *name;
@property(readonly, nonatomic) NSString *model;
@property(readonly, nonatomic) NSUUID *identifier;
- (id)description;
- (unsigned long long)hash;
- (BOOL)isEqual:(id)arg1;

@end

@interface SidecarDisplayManager: NSObject
{
    NSArray<SidecarDevice *> *_devices;
    NSArray<SidecarDevice *> *_recentDevices;
}

+ (SidecarDisplayManager*)sharedManager;
+ (BOOL)isSupported;
- (void)preferencesChanged;
- (void)disconnectFromDevice:(SidecarDevice *)arg1 completion:(void (^)(void))arg2;
- (void)connectToDevice:(SidecarDevice *)arg1 completion:(void (^)(void))arg2;
@property(readonly, nonatomic) NSArray<SidecarDevice *> *recentDevices;
@property(readonly, nonatomic) NSArray<SidecarDevice *> *connectedDevices;
@property(readonly, nonatomic) NSArray<SidecarDevice *> *devices;
- (void)preferencesChanged:(id)arg1;
- (id)configForDevice:(SidecarDevice *)arg1;
- (id)init;

@end

#endif /* Bridge_h */
