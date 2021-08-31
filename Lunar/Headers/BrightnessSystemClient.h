//
//  BrightnessSystemClient.h
//  Shifty
//
//  Created by Enrico Ghirardi on 02/01/2018.
//

#import <Foundation/Foundation.h>

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
