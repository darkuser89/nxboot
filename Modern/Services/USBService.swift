import Foundation
import ModernUSB

/// Device scanning, file I/O and injection are serialized away from the UI executor.
protocol USBServicing: Sendable {
    func scan() async throws -> [USBDevice]
    func send(_ payload: Payload, to id: UInt64) async throws -> Int
}

actor USBService: USBServicing {
    func scan() throws -> [USBDevice] {
        try NXUSBTransport.scan().map {
            USBDevice(id: $0.registryID, location: $0.locationID, vendor: $0.vendorID,
                      product: $0.productID, name: $0.name)
        }.sorted { $0.id < $1.id }
    }

    func send(_ payload: Payload, to id: UInt64) throws -> Int {
        let resolved = try PayloadFile.resolve(payload)
        let data = try PayloadFile.read(resolved.url)
        guard let url = Bundle.main.url(forResource: "intermezzo", withExtension: "bin") else {
            throw NSError(domain: "NXBootModern", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Der integrierte Relocator fehlt. Bitte die vollständige App verwenden."])
        }
        let relocator = try Data(contentsOf: url)
        try NXUSBTransport.sendPayload(data, registryID: id, relocator: relocator)
        return data.count
    }
}
