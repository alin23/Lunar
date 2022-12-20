//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "ExceptionCatcher.h"
#import "Extensions.h"
// #import "BrightnessSystemClient.h"
#import "CBBlueLightClient.h"
// #import "CBTrueToneClient.h"
// #import "CBAdaptationClient.h"
#import "DDC.h"
#import "DDC2.h"
#import "LaunchAtLoginController.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>
#import <OSD/OSDManager.h>
#import <MonitorPanel/MPDisplay.h>
#import <MonitorPanel/MPDisplayMgr.h>
#import <MonitorPanel/MPDisplayMode.h>
#import <MonitorPanel/MPDisplayPreset.h>
#import <MonitorPanel/CDStructures.h>

#include "libssh2.h"
#include "libssh2_sftp.h"
#include "libssh2_publickey.h"

#import <AppKit/AppKit.h>
@interface NSButtonCell (Private)
- (BOOL)_shouldDrawTextWithDisabledAppearance;
@end

extern int SLSSetDisplayContrast(float contrast);
double CoreDisplay_Display_GetUserBrightness(CGDirectDisplayID display);
double CoreDisplay_Display_GetLinearBrightness(CGDirectDisplayID display);
double CoreDisplay_Display_GetDynamicLinearBrightness(CGDirectDisplayID display);

void CoreDisplay_Display_SetUserBrightness(CGDirectDisplayID display, double brightness);
void CoreDisplay_Display_SetLinearBrightness(CGDirectDisplayID display, double brightness);
void CoreDisplay_Display_SetDynamicLinearBrightness(CGDirectDisplayID display, double brightness);

void CoreDisplay_Display_SetAutoBrightnessIsEnabled(CGDirectDisplayID, bool);

CFDictionaryRef CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID);

int DisplayServicesGetLinearBrightness(CGDirectDisplayID display, float *brightness);
int DisplayServicesSetLinearBrightness(CGDirectDisplayID display, float brightness);
int DisplayServicesGetBrightness(CGDirectDisplayID display, float *brightness);
int DisplayServicesSetBrightness(CGDirectDisplayID display, float brightness);
int DisplayServicesSetBrightnessSmooth(CGDirectDisplayID display, float brightness);
bool DisplayServicesCanChangeBrightness(CGDirectDisplayID display);
bool DisplayServicesIsSmartDisplay(CGDirectDisplayID display);
void DisplayServicesBrightnessChanged(CGDirectDisplayID display, double brightness);
void DisplayServicesBrightnessChangeNotificationImmediate(CGDirectDisplayID display, double brightness);

int DisplayServicesSetBrightnessWithType(CGDirectDisplayID display, UInt32 type, float brightness);
int DisplayServicesGetPowerMode(CGDirectDisplayID display);
int DisplayServicesSetPowerMode(CGDirectDisplayID display, UInt8 mode);
int DisplayServicesGetDevice(CGDirectDisplayID display);
int DisplayServicesGetBrightnessIncrement(CGDirectDisplayID display);
bool DisplayServicesNeedsBrightnessSmoothing(CGDirectDisplayID display);
int DisplayServicesEnableAmbientLightCompensation(CGDirectDisplayID display, bool enabled);
int DisplayServicesAmbientLightCompensationEnabled(CGDirectDisplayID display, bool *enabled);
bool DisplayServicesHasAmbientLightCompensation(CGDirectDisplayID display);
int DisplayServicesResetAmbientLight(CGDirectDisplayID display1, CGDirectDisplayID display2);
int DisplayServicesResetAmbientLightAll();
int DisplayServicesGetLinearBrightnessUsableRange(CGDirectDisplayID display, int *min, int *max);
NSArray* DisplayServicesCreateBrightnessTable(CGDirectDisplayID display, int samples);
int DisplayServicesRegisterForBrightnessChangeNotifications(CGDirectDisplayID display, CGDirectDisplayID displayObserver, CFNotificationCallback callback);
int DisplayServicesRegisterForAmbientLightCompensationNotifications(CGDirectDisplayID display, CGDirectDisplayID displayObserver, CFNotificationCallback callback);
int DisplayServicesUnregisterForBrightnessChangeNotifications(CGDirectDisplayID display, CGDirectDisplayID displayObserver);
int DisplayServicesUnregisterForAmbientLightCompensationNotifications(CGDirectDisplayID display, CGDirectDisplayID displayObserver);
bool DisplayServicesCanResetAmbientLight(CGDirectDisplayID display, UInt check);

void SLSSetAppearanceThemeLegacy(BOOL);
BOOL SLSGetAppearanceThemeLegacy();
