//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "DDC.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CommonCrypto/CommonDigest.h>

double CoreDisplay_Display_GetUserBrightness(CGDirectDisplayID display);
void CoreDisplay_Display_SetUserBrightness(CGDirectDisplayID display, double brightness);