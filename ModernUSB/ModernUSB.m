#import "ModernUSB.h"
#import <NXBootKit/NXBootKit.h>
#import <IOKit/IOCFPlugIn.h>

@implementation NXUSBRecord
@end

NXUSBKind NXClassifyUSB(uint16_t vendor, uint16_t product) {
    if (vendor == kTegraX1VendorID && product == kTegraX1ProductID) return NXUSBKindRCM;
    // Only the console's known USB identity; e.g. Pro Controllers (2009) are excluded.
    if (vendor == 0x057e && product == 0x2000) return NXUSBKindSwitch;
    return NXUSBKindOther;
}

NSUInteger NXPayloadSizeLimit(void) { return NXMaxFuseePayloadSize; }

static NSNumber *NXNumber(io_service_t service, CFStringRef key) {
    CFTypeRef value = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0);
    if (!value) return nil;
    id object = CFBridgingRelease(value);
    return [object isKindOfClass:NSNumber.class] ? object : nil;
}

static BOOL NXFail(NSError **error, NSInteger code, NSString *key, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"NXBootModern.USB" code:code
                                     userInfo:@{NSLocalizedDescriptionKey: message, @"NXBootMessageKey": key}];
    return NO;
}

@implementation NXUSBTransport

+ (NSArray<NXUSBRecord *> *)scanWithError:(NSError **)error {
    io_iterator_t iterator = 0;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault,
                            IOServiceMatching("IOUSBHostDevice"), &iterator);
    if (kr != KERN_SUCCESS) {
        NXFail(error, kr, @"error.usbScan", @"Couldn't read the list of USB devices.");
        return nil;
    }
    NSMutableArray *result = [NSMutableArray array];
    io_service_t service;
    while ((service = IOIteratorNext(iterator))) {
        @autoreleasepool {
            uint16_t vendor = NXNumber(service, CFSTR("idVendor")).unsignedShortValue;
            uint16_t product = NXNumber(service, CFSTR("idProduct")).unsignedShortValue;
            if (NXClassifyUSB(vendor, product) != NXUSBKindOther) {
                NXUSBRecord *record = [NXUSBRecord new];
                record.vendorID = vendor;
                record.productID = product;
                record.locationID = NXNumber(service, CFSTR("locationID")).unsignedIntValue;
                io_name_t name = {0};
                IORegistryEntryGetName(service, name);
                record.name = [NSString stringWithUTF8String:name] ?: @"USB Device";
                uint64_t registryID = 0;
                if (IORegistryEntryGetRegistryEntryID(service, &registryID) == KERN_SUCCESS) {
                    record.registryID = registryID;
                    [result addObject:record];
                }
            }
            IOObjectRelease(service);
        }
    }
    IOObjectRelease(iterator);
    return result;
}

+ (BOOL)sendPayload:(NSData *)payload registryID:(uint64_t)registryID
          relocator:(NSData *)relocator error:(NSError **)error {
    if (payload.length == 0 || payload.length > NXPayloadSizeLimit())
        return NXFail(error, 1, @"error.usbPayload", @"The payload is empty or exceeds the supported size.");
    if (relocator.length == 0 || relocator.length > 3648)
        return NXFail(error, 2, @"error.relocator", @"The bundled relocator is missing or invalid.");

    // Resolve the exact selected instance again immediately before any USB write.
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault,
                                           IORegistryEntryIDMatching(registryID));
    if (!service) return NXFail(error, 3, @"error.usbDisconnected", @"The selected USB device was disconnected.");
    uint16_t vendor = NXNumber(service, CFSTR("idVendor")).unsignedShortValue;
    uint16_t product = NXNumber(service, CFSTR("idProduct")).unsignedShortValue;
    if (!IOObjectConformsTo(service, "IOUSBHostDevice") ||
        NXClassifyUSB(vendor, product) != NXUSBKindRCM) {
        IOObjectRelease(service);
        return NXFail(error, 4, @"error.usbNotRCM", @"The selected device is not in RCM mode.");
    }

    IOCFPlugInInterface **plugin = NULL;
    SInt32 score = 0;
    kern_return_t kr = IOCreatePlugInInterfaceForService(service, kIOUSBDeviceUserClientTypeID,
                                                       kIOCFPlugInInterfaceID, &plugin, &score);
    IOObjectRelease(service);
    if (kr || !plugin) return NXFail(error, kr, @"error.usbAccess", @"Can't access USB. Close other injector apps and reconnect the cable.");
    NXUSBDevice *device = [NXUSBDevice new];
    device.name = @"Tegra RCM";
    kr = (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kNXUSBDeviceInterfaceUUID),
                                  (void **)&device->_intf);
    (*plugin)->Release(plugin);
    if (kr || !device->_intf) return NXFail(error, kr, @"error.usbInterface", @"Couldn't open the USB interface.");
    NXBootKitDebugEnabled = NO;
    NSString *message = nil;
    BOOL success = NXExec(device, relocator, payload, &message);
    if (!success) return NXFail(error, 5, @"error.usbTransfer", message ?: @"The USB transfer failed.");
    return YES;
}
@end
