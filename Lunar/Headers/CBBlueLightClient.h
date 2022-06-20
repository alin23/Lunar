
//
//  CBBlueLightClient.h
//  Shifty
//
//  Created by Nate Thompson and Cal Stephens on 5/5/17.
//
//

#import <Foundation/Foundation.h>

// Partial header for CBBlueLightClient in private CoreBrightness API
@interface CBBlueLightClient : NSObject

typedef struct {
    int hour;
    int minute;
} Time;

typedef struct {
    Time fromTime;
    Time toTime;
} CBSchedule;

typedef struct {
    BOOL active;
    BOOL enabled;
    BOOL sunSchedulePermitted;
    int mode;
    CBSchedule schedule;
    unsigned long long disableFlags;
    BOOL available;
} Status;

- (BOOL)setStrength:(float)strength commit:(BOOL)commit;
- (BOOL)setEnabled:(BOOL)enabled;
- (BOOL)setMode:(int)mode;
- (BOOL)setSchedule:(CBSchedule *)schedule;
- (BOOL)getStrength:(float *)strength;
- (BOOL)getBlueLightStatus:(Status *)status;
- (void)setStatusNotificationBlock:(void (^)(void))block;
+ (BOOL)supportsBlueLightReduction;
@end

@class BrightnessSystemClientInternal;

@interface BrightnessSystemClient : NSObject
{
    BrightnessSystemClientInternal *bsci;
}

- (void)registerNotificationBlock:(void (^)(void))callback forProperties:(NSArray *)properties;
- (void)registerNotificationBlock:(void (^)(void))callback;
- (BOOL)isAlsSupported;
- (id)copyPropertyForKey:(CFStringRef)key;
- (BOOL)setProperty:(id)property forKey:(CFStringRef)key;
- (void)dealloc;
- (id)init;

@end
