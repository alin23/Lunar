//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "DDC.h"
#import <CoreGraphics/CoreGraphics.h>
#import <CommonCrypto/CommonDigest.h>
#import <AmbientDisplay/DeviceGammaContext.h>

double CoreDisplay_Display_GetUserBrightness(CGDirectDisplayID display);
float CoreDisplay_Display_ContrastRatio(CGDirectDisplayID display);
void CoreDisplay_GetCurrentWhitePoint(long *x, long *y);
void CoreDisplay_Display_GetThermalCompensation(CGDirectDisplayID display, int *r, int *g, int *b);

