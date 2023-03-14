//
//  DDC.c
//  DDC Panel
//
//  Created by Jonathan Taylor on 7/10/09.
//  See http://github.com/jontaylor/DDC-CI-Tools-for-OS-X
//

#include "SharedDDC.h"
#include "DDC.h"
#include <stdarg.h>

#define kMaxRequests 10

const UInt8 ZEROARRAY[256] = { 0 };

void initDDCLogging(void) {
    logger = os_log_create("fyi.lunar.Lunar", "ddc");
}

bool IsLidClosed(void)
{
    bool isClosed = false;
    io_registry_entry_t rootDomain;
    mach_port_t masterPort;
    CFTypeRef clamShellStateRef = NULL;

    IOReturn ioReturn = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (ioReturn != 0) {
        os_log_error(logger, "Error on getting master port: %d", ioReturn);
        return false;
    }

    // Check to see if the "AppleClamshellClosed" property is in the PM root domain:
    rootDomain = IORegistryEntryFromPath(masterPort, kIOPowerPlane ":/IOPowerConnection/IOPMrootDomain");

    clamShellStateRef = IORegistryEntryCreateCFProperty(rootDomain, CFSTR("AppleClamshellState"), kCFAllocatorDefault, 0);
    if (clamShellStateRef == NULL) {
        if (rootDomain) {
            IOObjectRelease(rootDomain);
            return false;
        }
    }

    if (CFBooleanGetValue((CFBooleanRef)(clamShellStateRef)) == true) {
        isClosed = true;
    }

    if (rootDomain) {
        IOObjectRelease(rootDomain);
    }

    if (clamShellStateRef) {
        CFRelease(clamShellStateRef);
    }

    return isClosed;
}

static CFDataRef EDIDCreateFromFramebuffer(io_service_t framebuffer)
{
    io_iterator_t iter;
    io_service_t serv, displayPort = 0;

    if (IORegistryEntryGetChildIterator(framebuffer, kIOServicePlane, &iter) != KERN_SUCCESS) {
        os_log_error(logger, "Can't get child iterator for framebuffer port: %d", framebuffer);
        return NULL;
    }

    CFStringRef key = CFStringCreateWithCString(kCFAllocatorDefault, kIOProviderClassKey, kCFStringEncodingASCII);
    CFStringRef ioDisplayConnect = CFStringCreateWithCString(kCFAllocatorDefault, "IODisplayConnect", kCFStringEncodingASCII);
    CFDataRef edidData;

    while ((serv = IOIteratorNext(iter)) != MACH_PORT_NULL) {
        os_log_debug(logger, "Getting service class for child %d", serv);
        CFStringRef serviceClass = IORegistryEntrySearchCFProperty(serv, kIOServicePlane, key, kCFAllocatorDefault, kIORegistryIterateRecursively);
        if (serviceClass == NULL) {
            os_log_debug(logger, "No service class for child %d", serv);
            continue;
        }
        os_log_debug(logger, "Got service class for child %d", serv);

        if (CFStringCompare(ioDisplayConnect, serviceClass, 0) == 0 && IORegistryEntryGetChildEntry(serv, kIOServicePlane, &displayPort) == KERN_SUCCESS) {
            os_log_debug(logger, "Found display port for framebuffer %d: %d", framebuffer, displayPort);
        } else {
            CFRelease(serviceClass);
            continue;
        }

        os_log_debug(logger, "Getting info dict for display %d", serv);
        CFDictionaryRef info = IODisplayCreateInfoDictionary(displayPort, kIODisplayOnlyPreferredName);
        if (CFDictionaryGetValueIfPresent(info, CFSTR(kIODisplayEDIDKey), (const void**)&edidData)) {
            CFRetain(edidData);
            CFRelease(ioDisplayConnect);
            CFRelease(serviceClass);
            CFRelease(key);
            CFRelease(info);
            IOObjectRelease(iter);
            os_log_debug(logger, "Got EDID for display %d", displayPort);
            return edidData;
        }
        CFRelease(serviceClass);
        CFRelease(info);
    }

    CFRelease(key);
    CFRelease(ioDisplayConnect);
    IOObjectRelease(iter);
    os_log_error(logger, "No EDID for framebuffer %d", framebuffer);
    return NULL;
}

io_service_t IOFramebufferPortFromCGSServiceForDisplayNumber(CGDirectDisplayID displayID)
{
    io_service_t framebuffer = 0;
    if (CGSServiceForDisplayNumber != NULL) {
        // private API func is aliased to SLServiceForDisplayNumber within Skylight.framework, which CoreGraphics.framework links to
        // see https://objective-see.com/blog/blog_0x2C.html "reversing apple's 'screencapture' to programmatically grab desktop images"
        CGSServiceForDisplayNumber(displayID, &framebuffer);
    }
    return framebuffer;
}

io_service_t IOFramebufferPortFromCGDisplayIOServicePort(CGDirectDisplayID displayID)
{
    io_service_t framebuffer = 0;
    if (CGDisplayIOServicePort != NULL) {
        // legacy API call to get the IOFB's service port, was deprecated after macOS 10.9:
        //     https://developer.apple.com/library/mac/documentation/GraphicsImaging/Reference/Quartz_Services_Ref/index.html#//apple_ref/c/func/CGDisplayIOServicePort
        framebuffer = CGDisplayIOServicePort(displayID);
    }
    return framebuffer;
}

/*

 Iterate IOreg's device tree to find the IOFramebuffer mach service port that corresponds to a given CGDisplayID
 replaces CGDisplayIOServicePort: https://developer.apple.com/library/mac/documentation/GraphicsImaging/Reference/Quartz_Services_Ref/index.html#//apple_ref/c/func/CGDisplayIOServicePort
 based on: https://github.com/glfw/glfw/pull/192/files
 */
io_service_t IOFramebufferPortFromCGDisplayID(CGDirectDisplayID displayID, CFMutableDictionaryRef displayUUIDByEDID)
{
    io_iterator_t iter;
    io_service_t serv, servicePort = 0;
    CFUUIDRef displayUUID = CGDisplayCreateUUIDFromDisplayID(displayID);

    if (!displayUUID) {
        return 0;
    }

    kern_return_t err = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(IOFRAMEBUFFER_CONFORMSTO), &iter);

    if (err != KERN_SUCCESS) {
        CFRelease(displayUUID);
        IOObjectRelease(iter);
        return 0;
    }

    // now recurse the IOReg tree
    while ((serv = IOIteratorNext(iter)) != MACH_PORT_NULL) {
        CFDictionaryRef info;
        CFUUIDRef uuid;
        io_name_t name;
        CFIndex vendorID = 0, productID = 0, serialNumber = 0;
        CFNumberRef vendorIDRef, productIDRef, serialNumberRef;
        Boolean success = 0;

        os_log_debug(logger, "Getting EDID for framebuffer %d", serv);
        CFDataRef displayEDID = EDIDCreateFromFramebuffer(serv);
        if (displayEDID == NULL) {
            continue;
        }

        os_log_debug(logger, "Checking to see if EDID already exists");
        if (CFDictionaryGetValueIfPresent(displayUUIDByEDID, displayEDID, (const void**)&uuid)) {
            CFRetain(uuid);

            os_log_debug(logger, "EDID already exists");
            os_log_debug(logger, "Checking to see if EDID corresponds to display UUID");

            CFStringRef uuid1 = CFUUIDCreateString(kCFAllocatorDefault, displayUUID);
            CFStringRef uuid2 = CFUUIDCreateString(kCFAllocatorDefault, uuid);

            if (uuid1 && uuid2 && CFStringCompare(uuid1, uuid2, 0) != 0) {
                CFRelease(displayEDID);
                CFRelease(uuid1);
                CFRelease(uuid2);
                os_log_debug(logger, "UUIDs differ");
                continue;
            }
            if (uuid1) {
                CFRelease(uuid1);
            }
            if (uuid2) {
                CFRelease(uuid2);
            }
        }

        // get metadata from IOreg node
        IORegistryEntryGetName(serv, name);
        os_log_debug(logger, "Getting info dict for fb: %d", serv);
        info = IODisplayCreateInfoDictionary(serv, kIODisplayOnlyPreferredName);

        os_log_debug(logger, "Getting vendor for fb: %d", serv);
        if (CFDictionaryGetValueIfPresent(info, CFSTR(kDisplayVendorID), (const void**)&vendorIDRef)) {
            success = CFNumberGetValue(vendorIDRef, kCFNumberCFIndexType, &vendorID);
            os_log_debug(logger, "Got vendor %ld for fb: %d", (long)vendorID, serv);
        }

        os_log_debug(logger, "Getting product id for fb: %d", serv);
        if (CFDictionaryGetValueIfPresent(info, CFSTR(kDisplayProductID), (const void**)&productIDRef)) {
            success &= CFNumberGetValue(productIDRef, kCFNumberCFIndexType, &productID);
            os_log_debug(logger, "Got product id %ld for fb: %d", (long)productID, serv);
        }

        IOItemCount busCount;
        IOFBGetI2CInterfaceCount(serv, &busCount);

        if (!success || busCount < 1 || CGDisplayIsBuiltin(displayID)) {
            // this does not seem to be a DDC-enabled display, skip it
            CFRelease(displayEDID);
            CFRelease(info);
            continue;
        }

        os_log_debug(logger, "Getting serial number for fb: %d", serv);
        if (CFDictionaryGetValueIfPresent(info, CFSTR(kDisplaySerialNumber), (const void**)&serialNumberRef)) {
            CFNumberGetValue(serialNumberRef, kCFNumberCFIndexType, &serialNumber);
            os_log_debug(logger, "Got serial number %ld for fb: %d", (long)serialNumber, serv);
        }

        // compare IOreg's metadata to CGDisplay's metadata to infer if the IOReg's I2C monitor is the display for the given NSScreen.displayID
        if (CGDisplayVendorNumber(displayID) != (UInt32)vendorID || CGDisplayModelNumber(displayID) != (UInt32)productID || CGDisplaySerialNumber(displayID) != (UInt32)serialNumber) // SN is zero in lots of cases, so duplicate-monitors can confuse us :-/
        {
            CFRelease(displayEDID);
            CFRelease(info);
            continue;
        }

        servicePort = serv;
        CFDictionarySetValue(displayUUIDByEDID, displayEDID, displayUUID);
        CFRelease(displayEDID);
        CFRelease(displayUUID);
        CFRelease(info);
        IOObjectRelease(iter);
        return servicePort;
    }

    CFRelease(displayUUID);
    IOObjectRelease(iter);
    return 0;
}

dispatch_semaphore_t I2CRequestQueue(io_service_t i2c_device_id)
{
    static UInt64 queueCount = 0;
    static struct ReqQueue {
        uint32_t id;
        dispatch_semaphore_t queue;
    }* queues = NULL;
    dispatch_semaphore_t queue = NULL;
    if (!queues)
        queues = calloc(100, sizeof(*queues)); // FIXME: specify
    UInt64 i = 0;
    while (i < queueCount)
        if (queues[i].id == i2c_device_id)
            break;
        else
            i++;
    if (queues[i].id == i2c_device_id)
        queue = queues[i].queue;
    else
        queues[queueCount++] = (struct ReqQueue) { i2c_device_id, (queue = dispatch_semaphore_create(1)) };
    return queue;
}

bool FramebufferI2CRequest(io_service_t framebuffer, IOI2CRequest* request)
{
    dispatch_semaphore_t queue = I2CRequestQueue(framebuffer);
    dispatch_semaphore_wait(queue, DISPATCH_TIME_FOREVER);
    bool result = false;
    IOItemCount busCount;
    if (IOFBGetI2CInterfaceCount(framebuffer, &busCount) == KERN_SUCCESS) {
        IOOptionBits bus = 0;
        while (bus < busCount) {
            io_service_t interface;
            if (IOFBCopyI2CInterfaceForBus(framebuffer, bus++, &interface) != KERN_SUCCESS)
                continue;

            IOI2CConnectRef connect;
            if (IOI2CInterfaceOpen(interface, kNilOptions, &connect) == KERN_SUCCESS) {
                result = (IOI2CSendRequest(connect, kNilOptions, request) == KERN_SUCCESS);
                IOI2CInterfaceClose(connect, kNilOptions);
            }
            IOObjectRelease(interface);
            if (result)
                break;
        }
    }
    if (request->replyTransactionType == kIOI2CNoTransactionType)
        usleep(20000);
    dispatch_semaphore_signal(queue);
    return result && request->result == KERN_SUCCESS;
}

bool DDCWriteIntel(io_service_t framebuffer, struct DDCWriteCommand* write)
{
    IOI2CRequest request;
    UInt8 data[256];

    bzero(&request, sizeof(request));

    request.commFlags = 0;

    request.sendAddress = 0x6E;
    request.sendTransactionType = kIOI2CSimpleTransactionType;
    request.sendBuffer = (vm_address_t)&data[0];
    request.sendBytes = 7;

    data[0] = 0x51;
    data[1] = 0x84;
    data[2] = 0x03;
    data[3] = write->control_id;
    data[4] = (write->new_value) >> 8;
    data[5] = write->new_value & 255;
    data[6] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4] ^ data[5];

    request.replyTransactionType = kIOI2CNoTransactionType;
    request.replyBytes = 0;

    bool result = FramebufferI2CRequest(framebuffer, &request);
    return result;
}

long DDCDelayBase = 1; // nanoseconds

long DDCDelay(io_service_t framebuffer)
{
    // Certain displays / graphics cards require a long-enough delay to yield a response to DDC commands
    // Relying on retry will not help if the delay is too short.
    // kernel panics are possible if value is wrong
    // https://developer.apple.com/documentation/iokit/ioi2crequest/1410394-minreplydelay?language=objc

    CFStringRef ioRegPath = IORegistryEntryCopyPath(framebuffer, kIOServicePlane);
    if (CFStringFind(ioRegPath, CFSTR("/AMD"), kCFCompareCaseInsensitive).location != kCFNotFound) {
        CFRelease(ioRegPath);
        return DDCDelayBase + 30000000; // Team Red needs more time, as usual!
    }
    CFRelease(ioRegPath);
    return DDCDelayBase;
}

bool DDCReadIntel(io_service_t framebuffer, struct DDCReadCommand* read)
{
    IOI2CRequest request;
    UInt8 reply_data[11] = {};
    bool result = false;
    UInt8 data[128];

    long reply_timeout = DDCDelay(framebuffer) * kNanosecondScale;

    for (int i = 1; i <= kMaxRequests; i++) {
        bzero(&request, sizeof(request));

        request.commFlags = 0;
        request.sendAddress = 0x6E;
        request.sendTransactionType = kIOI2CSimpleTransactionType;
        request.sendBuffer = (vm_address_t)&data[0];
        request.sendBytes = 5;
        request.minReplyDelay = reply_timeout;

        data[0] = 0x51;
        data[1] = 0x82;
        data[2] = 0x01;
        data[3] = read->control_id;
        data[4] = 0x6E ^ data[0] ^ data[1] ^ data[2] ^ data[3];
#ifdef TT_SIMPLE
        request.replyTransactionType = kIOI2CSimpleTransactionType;
#elif defined TT_DDC
        request.replyTransactionType = kIOI2CDDCciReplyTransactionType;
#else
        request.replyTransactionType = SupportedTransactionType();
#endif
        request.replyAddress = 0x6F;
        request.replySubAddress = 0x51;

        request.replyBuffer = (vm_address_t)reply_data;
        request.replyBytes = sizeof(reply_data);

        result = FramebufferI2CRequest(framebuffer, &request);
        result = (result && reply_data[0] == request.sendAddress && reply_data[2] == 0x2 && reply_data[4] == read->control_id && reply_data[10] == (request.replyAddress ^ request.replySubAddress ^ reply_data[1] ^ reply_data[2] ^ reply_data[3] ^ reply_data[4] ^ reply_data[5] ^ reply_data[6] ^ reply_data[7] ^ reply_data[8] ^ reply_data[9]));

        if (result) { // checksum is ok
            if (i > 1) {
                os_log_debug(logger, "Tries required to get data: %d", i);
            }
            break;
        }

        if (request.result == kIOReturnUnsupportedMode)
            os_log_error(logger, "Unsupported Transaction Type!");

        // reset values and return 0, if data reading fails
        if (i >= kMaxRequests) {
            read->success = false;
            read->max_value = 0;
            read->current_value = 0;
            os_log_error(logger, "No data after %d tries!", i);
            return 0;
        }

        usleep(40000); // 40msec -> See DDC/CI Vesa Standard - 4.4.1 Communication Error Recovery
    }
    read->success = true;
    read->max_value = reply_data[7];
    read->current_value = reply_data[9];
    return result;
}

UInt32 SupportedTransactionType()
{
    kern_return_t kr;
    io_iterator_t io_objects;
    io_service_t io_service;

    kr = IOServiceGetMatchingServices(kIOMasterPortDefault,
                                      IOServiceNameMatching("IOFramebufferI2CInterface"), &io_objects);

    if (kr != KERN_SUCCESS) {
        os_log_error(logger, "Fatal - No matching service!");
        return 0;
    }

    UInt32 supportedType = 0;

    while ((io_service = IOIteratorNext(io_objects)) != MACH_PORT_NULL) {
        CFMutableDictionaryRef service_properties;
        CFIndex types = 0;
        CFNumberRef typesRef;

        kr = IORegistryEntryCreateCFProperties(io_service, &service_properties, kCFAllocatorDefault, kNilOptions);
        if (kr == KERN_SUCCESS) {
            if (CFDictionaryGetValueIfPresent(service_properties, CFSTR(kIOI2CTransactionTypesKey), (const void**)&typesRef))
                CFNumberGetValue(typesRef, kCFNumberCFIndexType, &types);

            if (types) {
#ifdef DEBUG
                os_log_debug(logger, "IOI2CTransactionTypes: 0x%02lx (%ld)", types, types);

                // kIOI2CNoTransactionType = 0
                if (0 == ((1 << kIOI2CNoTransactionType) & (UInt64)types)) {
                    os_log_error(logger, "IOI2CNoTransactionType                   unsupported ");
                } else {
                    os_log_debug(logger, "IOI2CNoTransactionType                   supported ");
                    supportedType = kIOI2CNoTransactionType;
                }

                // kIOI2CSimpleTransactionType = 1
                if (0 == ((1 << kIOI2CSimpleTransactionType) & (UInt64)types)) {
                    os_log_error(logger, "IOI2CSimpleTransactionType               unsupported ");
                } else {
                    os_log_debug(logger, "IOI2CSimpleTransactionType               supported ");
                    supportedType = kIOI2CSimpleTransactionType;
                }

                // kIOI2CDDCciReplyTransactionType = 2
                if (0 == ((1 << kIOI2CDDCciReplyTransactionType) & (UInt64)types)) {
                    os_log_error(logger, "IOI2CDDCciReplyTransactionType           unsupported ");
                } else {
                    os_log_debug(logger, "IOI2CDDCciReplyTransactionType           supported ");
                    supportedType = kIOI2CDDCciReplyTransactionType;
                }

                // kIOI2CCombinedTransactionType = 3
                if (0 == ((1 << kIOI2CCombinedTransactionType) & (UInt64)types)) {
                    os_log_error(logger, "IOI2CCombinedTransactionType             unsupported ");
                } else {
                    os_log_debug(logger, "IOI2CCombinedTransactionType             supported ");
                    // supportedType = kIOI2CCombinedTransactionType;
                }

                // kIOI2CDisplayPortNativeTransactionType = 4
                if (0 == ((1 << kIOI2CDisplayPortNativeTransactionType) & (UInt64)types)) {
                    os_log_error(logger, "IOI2CDisplayPortNativeTransactionType    unsupported");
                } else {
                    os_log_debug(logger, "IOI2CDisplayPortNativeTransactionType    supported ");
                    // supportedType = kIOI2CDisplayPortNativeTransactionType;
                    //  http://hackipedia.org/Hardware/video/connectors/DisplayPort/VESA%20DisplayPort%20Standard%20v1.1a.pdf
                    //  http://www.electronic-products-design.com/geek-area/displays/display-port
                }
#else
                // kIOI2CSimpleTransactionType = 1
                if (0 != ((1 << kIOI2CSimpleTransactionType) & (UInt64)types)) {
                    supportedType = kIOI2CSimpleTransactionType;
                }

                // kIOI2CDDCciReplyTransactionType = 2
                if (0 != ((1 << kIOI2CDDCciReplyTransactionType) & (UInt64)types)) {
                    supportedType = kIOI2CDDCciReplyTransactionType;
                }
#endif
            } else
                os_log_error(logger, "Fatal - No supported Transaction Types! ");

            CFRelease(service_properties);
            CFRelease(typesRef);
        }

        IOObjectRelease(io_service);

        // Mac OS offers three framebuffer devices, but we can leave here
        if (supportedType > 0)
            return supportedType;
    }

    return supportedType;
}

bool EDIDTestIntel(io_service_t framebuffer, struct EDID* edid, uint8_t edidData[256])
{
    IOI2CRequest request = {};
    /*! from https://opensource.apple.com/source/IOGraphics/IOGraphics-513.1/IOGraphicsFamily/IOKit/i2c/IOI2CInterface.h.auto.html
     *  not in https://developer.apple.com/reference/kernel/1659924-ioi2cinterface.h/ioi2crequest?changes=latest_beta&language=objc
     * @abstract A structure defining an I2C bus transaction.
     * @discussion This structure is used to request an I2C transaction consisting of a send (write) to and reply (read) from a device, either of which is optional, to be carried out atomically on an I2C bus.
     * @field __reservedA Set to zero.
     * @field result The result of the transaction. Common errors are kIOReturnNoDevice if there is no device responding at the given address, kIOReturnUnsupportedMode if the type of transaction is unsupported on the requested bus.
     * @field completion A completion routine to be executed when the request completes. If NULL is passed, the request is synchronous, otherwise it may execute asynchronously.
     * @field commFlags Flags that modify the I2C transaction type. The following flags are defined:<br>
     *      kIOI2CUseSubAddressCommFlag Transaction includes a subaddress.<br>
     * @field minReplyDelay Minimum delay as absolute time between send and reply transactions.
     * @field sendAddress I2C address to write.
     * @field sendSubAddress I2C subaddress to write.
     * @field __reservedB Set to zero.
     * @field sendTransactionType The following types of transaction are defined for the send part of the request:<br>
     *      kIOI2CNoTransactionType No send transaction to perform. <br>
     *      kIOI2CSimpleTransactionType Simple I2C message. <br>
     *      kIOI2CCombinedTransactionType Combined format I2C R/~W transaction. <br>
     * @field sendBuffer Pointer to the send buffer.
     * @field sendBytes Number of bytes to send. Set to actual bytes sent on completion of the request.
     * @field replyAddress I2C Address from which to read.
     * @field replySubAddress I2C Address from which to read.
     * @field __reservedC Set to zero.
     * @field replyTransactionType The following types of transaction are defined for the reply part of the request:<br>
     *      kIOI2CNoTransactionType No reply transaction to perform. <br>
     *      kIOI2CSimpleTransactionType Simple I2C message. <br>
     *      kIOI2CDDCciReplyTransactionType DDC/ci message (with embedded length). See VESA DDC/ci specification. <br>
     *      kIOI2CCombinedTransactionType Combined format I2C R/~W transaction. <br>
     * @field replyBuffer Pointer to the reply buffer.
     * @field replyBytes Max bytes to reply (size of replyBuffer). Set to actual bytes received on completion of the request.
     * @field __reservedD Set to zero.
     */

    UInt8 data[256] = {};
    request.sendAddress = 0xA0;
    request.sendTransactionType = kIOI2CSimpleTransactionType;
    request.sendBuffer = (vm_address_t)data;
    request.sendBytes = 0x01;
    data[0] = 0x00;
    request.replyAddress = 0xA1;
    request.replyTransactionType = kIOI2CSimpleTransactionType;
    request.replyBuffer = (vm_address_t)data;
    request.replyBytes = sizeof(data);
    if (!FramebufferI2CRequest(framebuffer, &request))
        return false;
    if (edid) {
        memcpy(edid, &data, 256);
        memcpy(edidData, &data, 256);
    }
    UInt32 i = 0;
    UInt8 sum = 0;
    while (i < request.replyBytes) {
        if (i % 256 == 0) {
            if (sum)
                break;
            sum = 0;
        }
        sum += data[i++];
    }
    return !sum;
}

