import XCTest
@testable import NXBootModern

final class USBRegistryMonitorTests: XCTestCase {
    /// Only registers IOKit notifications and drains registry objects; no USB device is opened.
    @MainActor
    func testNativeRegistrySubscriptionCanBeStoppedAndRestarted() async throws {
        let monitor = USBChangeMonitor()
        for _ in 0..<2 {
            let stream = try monitor.start()
            var iterator = stream.makeAsyncIterator()
            let initial: Void? = await iterator.next()
            XCTAssertNotNil(initial)
            monitor.stop()
            // A single already-buffered event may exist if a device changed during this check.
            while let _ = await iterator.next() {}
        }
        monitor.stop()
    }
}
