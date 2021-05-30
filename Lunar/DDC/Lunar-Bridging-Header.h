//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "ExceptionCatcher.h"
#import "CBBlueLightClient.h"
#import "DDC.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>
#import <OSD/OSDManager.h>

#include "libssh2.h"
#include "libssh2_sftp.h"
#include "libssh2_publickey.h"

double CoreDisplay_Display_GetUserBrightness(CGDirectDisplayID display);
void CoreDisplay_Display_SetUserBrightness(CGDirectDisplayID display, double brightness);
CFDictionaryRef CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID);

int DisplayServicesGetLinearBrightness(CGDirectDisplayID display, float *brightness);
int DisplayServicesSetLinearBrightness(CGDirectDisplayID display, float brightness);
