//
//  DDC.h
//  DDC Panel
//
//  Created by Jonathan Taylor on 7/10/09.
//  See ftp://ftp.cis.nctu.edu.tw/pub/csie/Software/X11/private/VeSaSpEcS/VESA_Document_Center_Monitor_Interface/mccsV3.pdf
//  See http://read.pudn.com/downloads110/ebook/456020/E-EDID%20Standard.pdf
//  See ftp://ftp.cis.nctu.edu.tw/pub/csie/Software/X11/private/VeSaSpEcS/VESA_Document_Center_Monitor_Interface/EEDIDrAr2.pdf
//

#ifndef DDC_Panel_DDC_h
#define DDC_Panel_DDC_h

#include <IOKit/i2c/IOI2CInterface.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/graphics/IOGraphicsLib.h>
#include <ApplicationServices/ApplicationServices.h>
#include "SharedDDC.h"

#define RESET 0x04
#define RESET_BRIGHTNESS_AND_CONTRAST 0x05
#define RESET_GEOMETRY 0x06
#define RESET_COLOR 0x08
#define BRIGHTNESS 0x10  //OK
#define CONTRAST 0x12 //OK
#define COLOR_PRESET_A                 0x14     // dell u2515h -> Presets: 4 = 5000K, 5 = 6500K, 6 = 7500K, 8 = 9300K, 9 = 10000K, 11 = 5700K, 12 = Custom Color
#define RED_GAIN 0x16
#define GREEN_GAIN 0x18
#define BLUE_GAIN 0x1A
#define AUTO_SIZE_CENTER 0x1E
#define WIDTH 0x22
#define HEIGHT 0x32
#define VERTICAL_POS	0x30
#define HORIZONTAL_POS 0x20
#define PINCUSHION_AMP 0x24
#define PINCUSHION_PHASE 0x42
#define KEYSTONE_BALANCE 0x40
#define PINCUSHION_BALANCE 0x26
#define TOP_PINCUSHION_AMP 0x46
#define TOP_PINCUSHION_BALANCE 0x48
#define BOTTOM_PINCUSHION_AMP 0x4A
#define BOTTOM_PINCUSHION_BALANCE 0x4C
#define VERTICAL_LINEARITY 0x3A
#define VERTICAL_LINEARITY_BALANCE 0x3C
#define HORIZONTAL_STATIC_CONVERGENCE 0x28
#define VERTICAL_STATIC_CONVERGENCE 0x28
#define MOIRE_CANCEL 0x56
#define INPUT_SOURCE 0x60
#define AUDIO_SPEAKER_VOLUME 0x62
#define RED_BLACK_LEVEL 0x6C
#define GREEN_BLACK_LEVEL 0x6E
#define BLUE_BLACK_LEVEL 0x70
#define ORIENTATION 0xAA
#define AUDIO_MUTE 0x8D
#define SETTINGS 0xB0                  //unsure on this one
#define ON_SCREEN_DISPLAY              0xCA     // read only   -> returns '1' (OSD closed) or '2' (OSD active)
#define OSD_LANGUAGE 0xCC
#define DPMS 0xD6
#define COLOR_PRESET_B                 0xDC     // dell u2515h -> Presets: 0 = Standard, 2 = Multimedia, 3 = Movie, 5 = Game
#define VCP_VERSION 0xDF
#define COLOR_PRESET_C                 0xE0     // dell u2515h -> Brightness on/off (0 or 1)
#define POWER_CONTROL 0xE1
#define TOP_LEFT_SCREEN_PURITY 0xE8
#define TOP_RIGHT_SCREEN_PURITY 0xE9
#define BOTTOM_LEFT_SCREEN_PURITY 0xE8
#define BOTTOM_RIGHT_SCREEN_PURITY 0xEB

UInt8 DEBUG_FLAG = 0;
FILE *logFile = NULL;
char *logPath = "/tmp/lunar.log";
bool logToFile(char* format, ...);

bool DDCWriteIntel(io_service_t framebuffer, struct DDCWriteCommand *write);
bool DDCReadIntel(io_service_t framebuffer, struct DDCReadCommand *read);
bool EDIDTestIntel(io_service_t framebuffer, struct EDID *edid, uint8_t edidData[256]);

io_service_t IOFramebufferPortFromCGDisplayID(CGDirectDisplayID displayID, CFMutableDictionaryRef displayUUIDByEDID);
io_service_t IOFramebufferPortFromCGSServiceForDisplayNumber(CGDirectDisplayID displayID);
io_service_t IOFramebufferPortFromCGDisplayIOServicePort(CGDirectDisplayID displayID);

UInt32 SupportedTransactionType(void);
void setDebugMode(UInt8);
void setLogPath(const char*, ssize_t);
bool IsLidClosed(void);

extern io_service_t CGDisplayIOServicePort(CGDirectDisplayID display) __attribute__((weak_import));
extern void CGSServiceForDisplayNumber(CGDirectDisplayID display, io_service_t* service) __attribute__((weak_import));

#endif
