#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NXUSBKind) {
    NXUSBKindOther = 0,
    NXUSBKindRCM = 1,
    NXUSBKindSwitch = 2
};

FOUNDATION_EXPORT NXUSBKind NXClassifyUSB(uint16_t vendor, uint16_t product);
FOUNDATION_EXPORT NSUInteger NXPayloadSizeLimit(void);

@interface NXUSBRecord : NSObject
@property(nonatomic) uint64_t registryID;
@property(nonatomic) uint32_t locationID;
@property(nonatomic) uint16_t vendorID;
@property(nonatomic) uint16_t productID;
@property(nonatomic, copy) NSString *name;
@end

/// All methods must be serialized by the caller. Scanning never opens or claims devices.
@interface NXUSBTransport : NSObject
+ (nullable NSArray<NXUSBRecord *> *)scanWithError:(NSError **)error;
+ (BOOL)sendPayload:(NSData *)payload
         registryID:(uint64_t)registryID
          relocator:(NSData *)relocator
              error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
