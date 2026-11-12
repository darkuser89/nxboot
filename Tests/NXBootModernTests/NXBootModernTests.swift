import XCTest
import ModernUSB
@testable import NXBootModern

final class NXBootModernTests: XCTestCase {
    private var temporary: URL!
    override func setUpWithError() throws {
        temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporary)
    }
    private func makeFile(_ data: Data, name: String = "payload.bin") throws -> URL {
        let url = temporary.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    func testUSBClassificationExcludesControllersAndUnrelatedDevices() {
        XCTAssertEqual(NXClassifyUSB(0x0955, 0x7321), .RCM)
        XCTAssertEqual(NXClassifyUSB(0x057e, 0x2000), .switch)
        XCTAssertEqual(NXClassifyUSB(0x057e, 0x2009), .other)
        XCTAssertEqual(NXClassifyUSB(0x0955, 0x0000), .other)
        XCTAssertEqual(NXClassifyUSB(0x05ac, 0x7321), .other)
    }

    func testPayloadBoundariesAndMissingFiles() throws {
        let valid = try makeFile(Data(repeating: 0x42, count: Int(NXPayloadSizeLimit())))
        XCTAssertEqual(try PayloadFile.read(valid).count, Int(NXPayloadSizeLimit()))
        let tooBig = try makeFile(Data(repeating: 0, count: Int(NXPayloadSizeLimit()) + 1), name: "large.bin")
        XCTAssertThrowsError(try PayloadFile.read(tooBig))
        XCTAssertThrowsError(try PayloadFile.read(makeFile(Data(), name: "empty.bin")))
        XCTAssertThrowsError(try PayloadFile.read(temporary))
        XCTAssertThrowsError(try PayloadFile.read(URL(string: "https://example.com/a.bin")!))
        XCTAssertThrowsError(try PayloadFile.read(temporary.appendingPathComponent("missing.bin")))
    }

    func testBridgeRejectsInvalidPayloadBeforeTouchingUSB() {
        XCTAssertThrowsError(try NXUSBTransport.sendPayload(Data(), registryID: 0, relocator: Data([1])))
        XCTAssertThrowsError(try NXUSBTransport.sendPayload(Data(repeating: 0, count: Int(NXPayloadSizeLimit()) + 1),
                                                            registryID: 0, relocator: Data([1])))
        XCTAssertThrowsError(try NXUSBTransport.sendPayload(Data([1]), registryID: 0, relocator: Data()))
    }

    func testBookmarkAndLibraryRoundTrip() throws {
        let url = try makeFile(Data([1, 2, 3]))
        let payload = Payload(name: "Hekate", bookmark: try PayloadFile.bookmark(url),
                              filename: url.lastPathComponent, byteCount: 3)
        XCTAssertEqual(try PayloadFile.resolve(payload).url.standardizedFileURL, url.standardizedFileURL)
        let store = LibraryStore(url: temporary.appendingPathComponent("state/library.json"))
        XCTAssertTrue(try store.load().isEmpty)
        try store.save([payload])
        XCTAssertEqual(try store.load(), [payload])
        try store.save([])
        XCTAssertTrue(try store.load().isEmpty)
        XCTAssertEqual(try Data(contentsOf: url), Data([1, 2, 3]))
    }

    @MainActor
    func testFavoriteRenameDuplicateImportAndRemovalPreserveOriginal() throws {
        let url = try makeFile(Data([1, 2, 3]))
        let store = LibraryStore(url: temporary.appendingPathComponent("library.json"))
        let model = AppModel(store: store)
        model.importFiles([url, url])
        XCTAssertNil(model.error)
        XCTAssertEqual(model.payloads.count, 1)
        let payload = try XCTUnwrap(model.selectedPayload)
        XCTAssertTrue(payload.isFavorite)
        XCTAssertFalse(model.canSend)
        model.toggleFavorite(payload)
        XCTAssertFalse(try XCTUnwrap(model.selectedPayload).isFavorite)
        model.rename(payload, to: "  My payload  ")
        XCTAssertEqual(model.selectedPayload?.name, "My payload")
        XCTAssertEqual(try store.load().first?.name, "My payload")
        model.remove(payload)
        XCTAssertTrue(model.payloads.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    func testCorruptLibraryIsNeverOverwritten() throws {
        let storeURL = try makeFile(Data("corrupt".utf8), name: "library.json")
        let original = try Data(contentsOf: storeURL)
        let model = AppModel(store: LibraryStore(url: storeURL))
        XCTAssertNotNil(model.error)
        model.importFiles([try makeFile(Data([1]))])
        XCTAssertEqual(try Data(contentsOf: storeURL), original)
        XCTAssertTrue(model.payloads.isEmpty)
    }

    func testUnknownLibraryVersionRejected() throws {
        let url = try makeFile(Data(#"{"version":2,"payloads":[]}"#.utf8), name: "library.json")
        XCTAssertThrowsError(try LibraryStore(url: url).load())
    }

    @MainActor
    func testDeviceTransitionsAndExplicitSelectionForMultipleConsoles() async throws {
        let fake = FakeUSB()
        let model = AppModel(store: LibraryStore(url: temporary.appendingPathComponent("library.json")), usb: fake)
        model.importFiles([try makeFile(Data([1, 2, 3]))])
        await model.refresh()
        XCTAssertEqual(model.statusTitle, "Keine Konsole erkannt")
        XCTAssertFalse(model.canSend)
        let normal = USBDevice(id: 1, location: 1, vendor: 0x057e, product: 0x2000, name: "Switch")
        await fake.setDevices([normal])
        await model.refresh()
        XCTAssertEqual(model.statusTitle, "Konsole verbunden · kein RCM")
        XCTAssertFalse(model.canSend)
        let first = USBDevice(id: 2, location: 2, vendor: 0x0955, product: 0x7321, name: "APX")
        let second = USBDevice(id: 3, location: 3, vendor: 0x0955, product: 0x7321, name: "APX")
        await fake.setDevices([first, second])
        await model.refresh()
        XCTAssertNil(model.selectedDeviceID)
        XCTAssertFalse(model.canSend)
        model.selectedDeviceID = second.id
        XCTAssertTrue(model.canSend)
        await fake.setDevices([first])
        await model.refresh()
        XCTAssertEqual(model.selectedDeviceID, first.id)
    }

    @MainActor
    func testSuccessfulSessionCannotBeSentTwiceAndReconnectRestoresSending() async throws {
        let fake = FakeUSB()
        let model = AppModel(store: LibraryStore(url: temporary.appendingPathComponent("library.json")), usb: fake)
        model.importFiles([try makeFile(Data([1, 2, 3]))])
        let rcm = USBDevice(id: 7, location: 1, vendor: 0x0955, product: 0x7321, name: "APX")
        await fake.setDevices([rcm])
        await model.refresh()
        XCTAssertTrue(model.canSend)
        let task = try XCTUnwrap(model.send())
        XCTAssertTrue(model.isSending)
        XCTAssertNil(model.send())
        await task.value
        XCTAssertFalse(model.isSending)
        XCTAssertFalse(model.canSend)
        XCTAssertNotNil(model.selectedPayload?.lastSentAt)
        let count = await fake.sendCount
        XCTAssertEqual(count, 1)
        await fake.setDevices([])
        await model.refresh()
        await fake.setDevices([rcm])
        await model.refresh()
        XCTAssertTrue(model.canSend)
        await fake.failScan()
        await model.refresh()
        XCTAssertNotNil(model.usbError)
        XCTAssertFalse(model.canSend)
        XCTAssertTrue(model.devices.isEmpty)
    }
    @MainActor
    func testAutomaticSendsChosenPayloadOncePerConnectionAndSurvivesScanErrors() async throws {
        let fake = FakeUSB()
        let model = AppModel(store: LibraryStore(url: temporary.appendingPathComponent("library.json")), usb: fake)
        model.importFiles([try makeFile(Data([1])), try makeFile(Data([2]), name: "other.bin")])
        let automatic = try XCTUnwrap(model.payloads.first)
        XCTAssertNotEqual(model.selectedPayloadID, automatic.id)
        model.configureAutomatic(payloadID: automatic.id, enabled: true)
        await model.refresh()
        let rcm = USBDevice(id: 10, location: 1, vendor: 0x0955, product: 0x7321, name: "APX")
        await fake.setDevices([rcm])
        await model.refresh()
        await model.refresh()
        var ids = await fake.sentPayloadIDs
        XCTAssertEqual(ids, [automatic.id])
        await fake.failScan()
        await model.refresh()
        await fake.setDevices([rcm])
        await model.refresh()
        ids = await fake.sentPayloadIDs
        XCTAssertEqual(ids.count, 1)
        await fake.setDevices([])
        await model.refresh()
        await fake.setDevices([rcm])
        await model.refresh()
        ids = await fake.sentPayloadIDs
        XCTAssertEqual(ids, [automatic.id, automatic.id])
    }

    @MainActor
    func testAutomaticWaitsWhenEnabledOnExistingConnectionAndWithMultipleDevices() async throws {
        let fake = FakeUSB()
        let model = AppModel(store: LibraryStore(url: temporary.appendingPathComponent("library.json")), usb: fake)
        model.importFiles([try makeFile(Data([1]))])
        let payload = try XCTUnwrap(model.selectedPayload)
        let one = USBDevice(id: 1, location: 1, vendor: 0x0955, product: 0x7321, name: "APX")
        let two = USBDevice(id: 2, location: 2, vendor: 0x0955, product: 0x7321, name: "APX")
        await fake.setDevices([one])
        await model.refresh()
        model.configureAutomatic(payloadID: payload.id, enabled: true)
        await model.refresh()
        var count = await fake.sendCount
        XCTAssertEqual(count, 0)
        await fake.setDevices([one, two])
        await model.refresh()
        count = await fake.sendCount
        XCTAssertEqual(count, 0)
        await fake.setDevices([two])
        await model.refresh()
        count = await fake.sendCount
        XCTAssertEqual(count, 0)
        model.configureAutomatic(payloadID: payload.id, enabled: false)
        await fake.setDevices([])
        await model.refresh()
        await fake.setDevices([one])
        await model.refresh()
        count = await fake.sendCount
        XCTAssertEqual(count, 0)
    }

    @MainActor
    func testAutomaticSettingsPersistAndRemovingPayloadDisablesAutomatic() throws {
        let store = LibraryStore(url: temporary.appendingPathComponent("library.json"))
        let model = AppModel(store: store, usb: FakeUSB())
        model.importFiles([try makeFile(Data([1]))])
        let payload = try XCTUnwrap(model.selectedPayload)
        XCTAssertFalse(model.automaticEnabled)
        model.configureAutomatic(payloadID: payload.id, enabled: true)
        model.toggleFavorite(payload)
        let restored = AppModel(store: store, usb: FakeUSB())
        XCTAssertTrue(restored.automaticEnabled)
        XCTAssertEqual(restored.automaticPayloadID, payload.id)
        restored.remove(payload)
        XCTAssertFalse(restored.automaticEnabled)
        XCTAssertNil(restored.automaticPayloadID)
        XCTAssertFalse(try store.loadState().automaticEnabled)
        let oldURL = try makeFile(Data(#"{"version":1,"payloads":[]}"#.utf8), name: "old.json")
        XCTAssertFalse(try LibraryStore(url: oldURL).loadState().automaticEnabled)
    }

    @MainActor
    func testAutomaticFailureDoesNotRetryAndStartupCanDetectAnExistingDevice() async throws {
        let store = LibraryStore(url: temporary.appendingPathComponent("library.json"))
        let initial = AppModel(store: store, usb: FakeUSB())
        initial.importFiles([try makeFile(Data([1]))])
        initial.configureAutomatic(payloadID: initial.selectedPayloadID, enabled: true)
        let fake = FakeUSB()
        await fake.setDevices([USBDevice(id: 1, location: 1, vendor: 0x0955, product: 0x7321, name: "APX")])
        await fake.failSend()
        let restored = AppModel(store: store, usb: fake)
        await restored.refresh()
        await restored.refresh()
        let count = await fake.sendCount
        XCTAssertEqual(count, 1)
        XCTAssertNotNil(restored.error)
    }
    @MainActor
    func testUnchangedScansDoNotInvalidateTheUI() async throws {
        let fake = FakeUSB()
        let model = AppModel(store: LibraryStore(url: temporary.appendingPathComponent("library.json")), usb: fake)
        var updates = 0
        let observation = model.objectWillChange.sink { updates += 1 }
        await model.refresh()
        await model.refresh()
        XCTAssertEqual(updates, 0)
        await fake.failScan()
        await model.refresh()
        let errorUpdates = updates
        await model.refresh()
        XCTAssertEqual(updates, errorUpdates)
        withExtendedLifetime(observation) {}
    }

    @MainActor
    func testRejectedSendCannotChangeSelection() async throws {
        let fake = FakeUSB()
        let model = AppModel(store: LibraryStore(url: temporary.appendingPathComponent("library.json")), usb: fake)
        model.importFiles([try makeFile(Data([1])), try makeFile(Data([2]), name: "second.bin")])
        let first = model.payloads[0], second = model.payloads[1]
        XCTAssertEqual(model.selectedPayloadID, second.id)
        XCTAssertNil(model.send(first))
        XCTAssertEqual(model.selectedPayloadID, second.id)
        await fake.setDevices([USBDevice(id: 1, location: 1, vendor: 0x0955, product: 0x7321, name: "APX")])
        await model.refresh()
        let send = try XCTUnwrap(model.send(first))
        XCTAssertNil(model.send(second))
        XCTAssertEqual(model.selectedPayloadID, first.id)
        await send.value
        let sent = await fake.sentPayloadIDs
        XCTAssertEqual(sent, [first.id])
    }

    @MainActor
    func testMonitoringScansOnlyAtStartupAndOnEventsAndStopsCleanly() async throws {
        let fake = FakeUSB()
        let changes = FakeUSBChanges()
        let model = AppModel(store: LibraryStore(url: temporary.appendingPathComponent("library.json")),
                             usb: fake, changeMonitor: changes)
        let initial = expectation(description: "Initial scan")
        let event = expectation(description: "Event scan")
        await fake.observeScans { count in
            if count == 1 { initial.fulfill() }
            if count == 2 { event.fulfill() }
        }
        let monitor = Task { await model.monitor() }
        await fulfillment(of: [initial], timeout: 2)
        try await Task.sleep(for: .milliseconds(1150))
        let idleScans = await fake.scanCount
        XCTAssertEqual(idleScans, 1)
        changes.emit()
        await fulfillment(of: [event], timeout: 2)
        monitor.cancel()
        await monitor.value
        XCTAssertEqual(changes.stopCount, 1)
        changes.emit()
        let stoppedScans = await fake.scanCount
        XCTAssertEqual(stoppedScans, 2)
        let restart = expectation(description: "Restarted scan")
        await fake.observeScans { count in if count == 3 { restart.fulfill() } }
        let restarted = Task { await model.monitor() }
        await fulfillment(of: [restart], timeout: 2)
        restarted.cancel()
        await restarted.value
        XCTAssertEqual(changes.startCount, 2)
        XCTAssertEqual(changes.stopCount, 2)
    }
}

@MainActor
private final class FakeUSBChanges: USBChangeObserving {
    private var continuation: AsyncStream<Void>.Continuation?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    func start() -> AsyncStream<Void> {
        startCount += 1
        let pair = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuation = pair.continuation
        continuation?.yield(())
        return pair.stream
    }
    func emit() { continuation?.yield(()) }
    func stop() { stopCount += 1; continuation?.finish(); continuation = nil }
}

private actor FakeUSB: USBServicing {
    private var devices: [USBDevice] = []
    private var scanFails = false
    private(set) var sendCount = 0
    private(set) var sentPayloadIDs: [UUID] = []
    private var sendFails = false
    private(set) var scanCount = 0
    private var scanObserver: (@Sendable (Int) -> Void)?
    func observeScans(_ observer: @escaping @Sendable (Int) -> Void) { scanObserver = observer }
    func setDevices(_ value: [USBDevice]) { devices = value; scanFails = false }
    func failScan() { scanFails = true }
    func failSend() { sendFails = true }
    func scan() throws -> [USBDevice] {
        scanCount += 1
        scanObserver?(scanCount)
        if scanFails { throw NSError(domain: "Test", code: 1) }
        return devices
    }
    func send(_ payload: Payload, to id: UInt64) throws -> Int {
        sendCount += 1
        sentPayloadIDs.append(payload.id)
        if sendFails { throw NSError(domain: "Test", code: 2) }
        return 3
    }
}
