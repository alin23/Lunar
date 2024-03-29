/*
* This header is generated by classdump-dyld 1.0
* on Friday, February 12, 2021 at 12:42:55 AM Eastern European Standard Time
* Operating System: Version 14.4 (Build 18D52)
* Image Source: /System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness
* classdump-dyld is licensed under GPLv3, Copyright © 2013-2016 by Elias Limneos.
*/

@class BrightnessSystemClient;

@interface CBAdaptationClient : NSObject {

    BrightnessSystemClient* bsc;
    BOOL ownsClient;
    int _mode;
    BOOL _modeSet;
    BOOL _supported;
}
@property (assign) BOOL supported; //@synthesize supported=_supported - In the implementation block
+ (BOOL)supportsAdaptation;
- (id)init;
- (BOOL)overrideStrengths:(float*)arg1 forModes:(int*)arg2 nModes:(int)arg3;
- (BOOL)setEnabled:(BOOL)arg1;
- (BOOL)animateFromWeakestAdaptationModeInArray:(int*)arg1 withLength:(int)arg2 toWeakestInArray:(int*)arg3 withLength:(int)arg4 withProgress:(float)arg5 andPeriod:(float)arg6;
- (BOOL)supported;
- (BOOL)getEnabled;
- (int)getAdaptationMode;
- (id)initWithClientObj:(id)arg1;
- (void)setSupported:(BOOL)arg1;
- (BOOL)getStrengths:(float*)arg1 nStrengths:(int)arg2;
- (void)dealloc;
- (BOOL)setAdaptationMode:(int)arg1 withPeriod:(float)arg2;
- (BOOL)setWeakestAdaptationModeFromArray:(int*)arg1 withLength:(int)arg2 andPeriod:(float)arg3;
@end
