import Foundation
import IOKit

@MainActor
protocol USBChangeObserving: AnyObject {
    func start() throws -> AsyncStream<Void>
    func stop()
}

/// Registry notifications only: observing never opens or claims a USB device.
@MainActor
final class USBChangeMonitor: USBChangeObserving {
    private var port: IONotificationPortRef?
    private var source: CFRunLoopSource?
    private var iterators: [io_iterator_t] = []
    private var continuation: AsyncStream<Void>.Continuation?

    func start() throws -> AsyncStream<Void> {
        stop()
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { throw failure() }
        self.port = port
        guard let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() else {
            stop()
            throw failure()
        }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        let pair = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation = pair.continuation
        do {
            for (vendor, product) in [(0x0955, 0x7321), (0x057e, 0x2000)] {
                for event in [kIOFirstMatchNotification, kIOTerminatedNotification] {
                    guard let matching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary? else {
                        throw failure()
                    }
                    matching["idVendor"] = vendor
                    matching["idProduct"] = product
                    var iterator: io_iterator_t = 0
                    let status = IOServiceAddMatchingNotification(port, event, matching,
                        Self.changed, Unmanaged.passUnretained(self).toOpaque(), &iterator)
                    guard status == KERN_SUCCESS else { throw failure() }
                    iterators.append(iterator)
                    Self.drain(iterator)
                }
            }
            pair.continuation.yield(())
            return pair.stream
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        if let port { IONotificationPortDestroy(port) }
        port = nil
        for iterator in iterators { IOObjectRelease(iterator) }
        iterators.removeAll()
        continuation?.finish()
        continuation = nil
    }

    deinit {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let port { IONotificationPortDestroy(port) }
        for iterator in iterators { IOObjectRelease(iterator) }
    }

    private nonisolated static let changed: IOServiceMatchingCallback = { context, iterator in
        USBChangeMonitor.drain(iterator)
        // The notification source is attached exclusively to the main run loop.
        MainActor.assumeIsolated {
            guard let context else { return }
            let monitor = Unmanaged<USBChangeMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.continuation?.yield(())
        }
    }

    private nonisolated static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 { IOObjectRelease(service) }
    }

    private func failure() -> NSError {
        NSError(domain: "NXBootModern.USBMonitor", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "USB-Ereignismeldungen sind nicht verfügbar."])
    }
}
