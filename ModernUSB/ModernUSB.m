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

static BOOL NXFail(NSError **error, NSInteger code, NSString *message) {
    if (error) *error = [NSError errorWithDomain:@"NXBootModern.USB" code:code
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
    return NO;
}

@implementation NXUSBTransport

+ (NSArray<NXUSBRecord *> *)scanWithError:(NSError **)error {
    io_iterator_t iterator = 0;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault,
                            IOServiceMatching("IOUSBHostDevice"), &iterator);
    if (kr != KERN_SUCCESS) {
        NXFail(error, kr, @"Die USB-Geräteliste konnte nicht gelesen werden.");
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
                record.name = [NSString stringWithUTF8String:name] ?: @"USB-Gerät";
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
        return NXFail(error, 1, @"Der Payload ist leer oder überschreitet die unterstützte Größe.");
    if (relocator.length == 0 || relocator.length > 3648)
        return NXFail(error, 2, @"Der integrierte Relocator fehlt oder ist ungültig.");

    // Resolve the exact selected instance again immediately before any USB write.
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault,
                                           IORegistryEntryIDMatching(registryID));
    if (!service) return NXFail(error, 3, @"Das ausgewählte USB-Gerät wurde getrennt.");
    uint16_t vendor = NXNumber(service, CFSTR("idVendor")).unsignedShortValue;
    uint16_t product = NXNumber(service, CFSTR("idProduct")).unsignedShortValue;
    if (!IOObjectConformsTo(service, "IOUSBHostDevice") ||
        NXClassifyUSB(vendor, product) != NXUSBKindRCM) {
        IOObjectRelease(service);
        return NXFail(error, 4, @"Das ausgewählte Gerät ist nicht im RCM-Modus.");
    }

    IOCFPlugInInterface **plugin = NULL;
    SInt32 score = 0;
    kern_return_t kr = IOCreatePlugInInterfaceForService(service, kIOUSBDeviceUserClientTypeID,
                                                       kIOCFPlugInInterfaceID, &plugin, &score);
    IOObjectRelease(service);
    if (kr || !plugin) return NXFail(error, kr, @"USB-Zugriff nicht möglich. Andere Injector-Apps schließen und das Kabel neu verbinden.");
    NXUSBDevice *device = [NXUSBDevice new];
    device.name = @"Tegra RCM";
    kr = (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kNXUSBDeviceInterfaceUUID),
                                  (void **)&device->_intf);
    (*plugin)->Release(plugin);
    if (kr || !device->_intf) return NXFail(error, kr, @"Die USB-Schnittstelle konnte nicht geöffnet werden.");
    NXBootKitDebugEnabled = NO;
    NSString *message = nil;
    BOOL success = NXExec(device, relocator, payload, &message);
    if (!success) return NXFail(error, 5, message ?: @"Die USB-Übertragung ist fehlgeschlagen.");
    return YES;
}
@end
