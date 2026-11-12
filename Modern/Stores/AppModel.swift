import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var payloads: [Payload] = []
    @Published private(set) var devices: [USBDevice] = []
    @Published private(set) var activity: [Activity] = []
    @Published private(set) var isSending = false
    @Published private(set) var usbError: String?
    @Published private(set) var lastResult: String?
    @Published private(set) var automaticPayloadID: UUID?
    @Published private(set) var automaticEnabled = false
    @Published var error: String?
    @Published var selectedPayloadID: UUID?
    @Published var selectedDeviceID: UInt64?
    @Published var section: LibrarySection? = .all
    @Published var search = ""
    private let store: LibraryStore
    private let usb: any USBServicing
    private let changeMonitor: any USBChangeObserving
    private var didStart = false
    private var isRefreshing = false
    private var canWriteLibrary = true
    private var usedConnections = Set<UInt64>()
    private var observedRCMConnections = Set<UInt64>()

    init(store: LibraryStore = .standard, usb: any USBServicing = USBService(),
         changeMonitor: (any USBChangeObserving)? = nil) {
        self.store = store
        self.usb = usb
        self.changeMonitor = changeMonitor ?? USBChangeMonitor()
        do {
            let state = try store.loadState()
            payloads = state.payloads
            automaticPayloadID = state.automaticPayloadID
            automaticEnabled = state.automaticEnabled
            selectedPayloadID = payloads.first?.id
        } catch {
            canWriteLibrary = false
            self.error = "Mediathek konnte nicht geladen werden: \(error.localizedDescription)"
        }
    }

    var selectedPayload: Payload? { payloads.first { $0.id == selectedPayloadID } }
    var automaticPayload: Payload? { payloads.first { $0.id == automaticPayloadID } }
    var rcmDevices: [USBDevice] { devices.filter(\.isRCM) }
    var selectedDevice: USBDevice? { rcmDevices.first { $0.id == selectedDeviceID } }
    var canSend: Bool {
        canSendToDevice && selectedPayload != nil
    }
    var canSendToDevice: Bool {
        !isSending && usbError == nil && selectedDevice != nil &&
        !usedConnections.contains(selectedDeviceID ?? 0)
    }
    var filteredPayloads: [Payload] {
        payloads.filter {
            (section != .favorites || $0.isFavorite) &&
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) ||
             $0.filename.localizedCaseInsensitiveContains(search))
        }
    }
    var statusTitle: String {
        if isSending { return "Payload wird gesendet" }
        if usbError != nil { return "USB-Erkennung nicht verfügbar" }
        if let id = selectedDeviceID, usedConnections.contains(id) { return "RCM · bereits gesendet" }
        if !rcmDevices.isEmpty { return "RCM erkannt" }
        if !devices.isEmpty { return "Konsole verbunden · kein RCM" }
        return "Keine Konsole erkannt"
    }
    var statusDetail: String {
        if isSending { return "Bitte USB-Kabel angeschlossen lassen." }
        if let usbError { return usbError }
        if !rcmDevices.isEmpty {
            if let id = selectedDeviceID, usedConnections.contains(id) {
                return "Startanforderung bereits gesendet. Für einen weiteren Versuch erneut in RCM verbinden."
            }
            return "\(rcmDevices.count == 1 ? "Ein Gerät ist" : "\(rcmDevices.count) Geräte sind") über USB im RCM-Modus erreichbar."
        }
        if !devices.isEmpty { return "Zum Senden muss die Konsole im RCM-Modus verbunden sein." }
        return "Konsole im RCM-Modus mit einem USB-Datenkabel verbinden."
    }

    func monitor() async {
        guard !didStart else { return }
        didStart = true
        defer { changeMonitor.stop(); didStart = false }
        do {
            let changes = try changeMonitor.start()
            for await _ in changes {
                guard !Task.isCancelled else { break }
                await refresh()
                // Only a failed scan needs timed retries; a healthy idle app has no polling timer.
                while usbError != nil, !Task.isCancelled {
                    try await Task.sleep(for: .seconds(1))
                    await refresh()
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            addActivity("USB-Ereignisse nicht verfügbar; automatische Statusabfrage wird verwendet.", isError: true)
            while !Task.isCancelled {
                await refresh()
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
            }
        }
    }

    func refresh() async {
        guard !isRefreshing, !isSending else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let snapshot = try await usb.scan()
            let rcmIDs = Set(snapshot.filter(\.isRCM).map(\.id))
            let newlyDetected = rcmIDs.subtracting(observedRCMConnections)
            // Only a successful scan can confirm a disconnection; errors must not re-arm auto-send.
            observedRCMConnections = rcmIDs
            if usbError != nil {
                addActivity("USB-Erkennung wieder verfügbar.")
                usbError = nil
            }
            if snapshot != devices {
                let old = Set(devices.map(\.id)), new = Set(snapshot.map(\.id))
                for device in snapshot where !old.contains(device.id) {
                    addActivity("\(device.title) verbunden · \(device.identity)")
                }
                if !old.subtracting(new).isEmpty { addActivity("USB-Verbindung getrennt.") }
                devices = snapshot
            }
            // Never reuse a successfully consumed RCM session until its instance disappears.
            usedConnections.formIntersection(Set(snapshot.map(\.id)))
            if selectedDevice == nil {
                let id = rcmDevices.count == 1 ? rcmDevices.first?.id : nil
                if id != selectedDeviceID { selectedDeviceID = id }
            }
            if automaticEnabled, !isSending, let payload = automaticPayload, !newlyDetected.isEmpty {
                if rcmDevices.count == 1, let id = rcmDevices.first?.id,
                   newlyDetected.contains(id), !usedConnections.contains(id) {
                    selectedDeviceID = id
                    addActivity("Automatisch: \(payload.name)")
                    if let task = send(payload) { await task.value }
                } else if rcmDevices.count > 1 {
                    addActivity("Automatik wartet: mehrere RCM-Geräte. Bitte manuell senden.")
                }
            }
        } catch {
            if usbError != error.localizedDescription {
                addActivity(error.localizedDescription, isError: true)
                usbError = error.localizedDescription
            }
            if !devices.isEmpty { devices = [] }
            if selectedDeviceID != nil { selectedDeviceID = nil }
        }
    }

    func configureAutomatic(payloadID: UUID?, enabled: Bool) {
        guard !isSending else { return }
        let id = payloadID.flatMap { id in payloads.contains { $0.id == id } ? id : nil }
        guard automaticPayloadID != id || automaticEnabled != (enabled && id != nil) else { return }
        do {
            guard canWriteLibrary else { throw PayloadError.unsupportedLibrary }
            try store.save(payloads, automaticPayloadID: id, automaticEnabled: enabled && id != nil)
            automaticPayloadID = id
            automaticEnabled = enabled && id != nil
        } catch { report(error) }
    }

    func chooseFiles(replacing id: UUID? = nil) {
        let panel = NSOpenPanel()
        panel.title = id == nil ? "Payloads hinzufügen" : "Payload-Datei neu zuordnen"
        panel.allowedContentTypes = [UTType(filenameExtension: "bin") ?? .data]
        panel.allowsMultipleSelection = id == nil
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        importFiles(panel.urls, replacing: id)
    }

    func importFiles(_ urls: [URL], replacing id: UUID? = nil) {
        guard !isSending else { return }
        do {
            var next = payloads
            var selection: UUID?
            var knownURLs: [URL: UUID] = [:]
            for payload in next {
                if let url = try? PayloadFile.resolve(payload).url.standardizedFileURL {
                    knownURLs[url] = payload.id
                }
            }
            for url in urls {
                let data = try PayloadFile.read(url)
                let bookmark = try PayloadFile.bookmark(url)
                if let id, let index = next.firstIndex(where: { $0.id == id }) {
                    next[index].bookmark = bookmark
                    next[index].filename = url.lastPathComponent
                    next[index].byteCount = data.count
                    selection = id
                } else if let duplicate = knownURLs[url.standardizedFileURL] {
                    selection = duplicate
                } else {
                    let payload = Payload(name: url.deletingPathExtension().lastPathComponent,
                                          bookmark: bookmark, filename: url.lastPathComponent,
                                          byteCount: data.count)
                    next.append(payload)
                    knownURLs[url.standardizedFileURL] = payload.id
                    selection = payload.id
                }
            }
            try commit(next)
            selectedPayloadID = selection
            section = .all
            search = ""
            if !urls.isEmpty { addActivity("\(urls.count) Payload-Datei(en) zugeordnet.") }
        } catch { report(error) }
    }

    func toggleFavorite(_ payload: Payload) {
        var next = payloads
        guard let index = next.firstIndex(where: { $0.id == payload.id }) else { return }
        next[index].isFavorite.toggle()
        do { try commit(next) } catch { report(error) }
    }

    func rename(_ payload: Payload, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var next = payloads
        guard let index = next.firstIndex(where: { $0.id == payload.id }) else { return }
        next[index].name = name
        do { try commit(next) } catch { report(error) }
    }

    func remove(_ payload: Payload) {
        do {
            try commit(payloads.filter { $0.id != payload.id })
            if selectedPayloadID == payload.id { selectedPayloadID = payloads.first?.id }
        } catch { report(error) }
    }

    func reveal(_ payload: Payload) {
        do { NSWorkspace.shared.activateFileViewerSelecting([try PayloadFile.resolve(payload).url]) }
        catch { report(error) }
    }

    @discardableResult
    func send(_ payload: Payload? = nil) -> Task<Void, Never>? {
        guard canSendToDevice,
              let payload = payloads.first(where: { $0.id == (payload?.id ?? selectedPayloadID) }),
              let device = selectedDevice else { return nil }
        selectedPayloadID = payload.id
        isSending = true
        lastResult = nil
        addActivity("Sende \(payload.name) an \(device.identity)…")
        return Task {
            do {
                let bytes = try await usb.send(payload, to: device.id)
                usedConnections.insert(device.id)
                lastResult = "\(bytes.formatted()) Bytes übertragen · Start angefordert. Der Start auf der Konsole ist nicht bestätigt."
                addActivity("\(payload.name): Übertragung abgeschlossen, Start angefordert.")
                var next = payloads
                if let index = next.firstIndex(where: { $0.id == payload.id }) {
                    next[index].lastSentAt = Date()
                    next[index].byteCount = bytes
                    do { try commit(next) }
                    catch { report(error) }
                }
            } catch {
                report(error)
                // Partial USB transfers also consume the session; do not blindly send twice.
                if (error as NSError).domain == "NXBootModern.USB" {
                    usedConnections.insert(device.id)
                    lastResult = "USB-Übertragung fehlgeschlagen. Für einen neuen Versuch erneut in RCM verbinden."
                } else {
                    lastResult = "Die Datei konnte nicht gesendet werden. Bitte den Dateiverweis prüfen."
                }
            }
            isSending = false
            await refresh()
        }
    }

    private func commit(_ next: [Payload]) throws {
        guard canWriteLibrary else { throw PayloadError.unsupportedLibrary }
        guard next != payloads else { return }
        let id = automaticPayloadID.flatMap { id in next.contains { $0.id == id } ? id : nil }
        try store.save(next, automaticPayloadID: id, automaticEnabled: automaticEnabled && id != nil)
        payloads = next
        automaticPayloadID = id
        automaticEnabled = automaticEnabled && id != nil
    }
    private func report(_ error: Error) {
        self.error = error.localizedDescription
        addActivity(error.localizedDescription, isError: true)
    }
    private func addActivity(_ message: String, isError: Bool = false) {
        activity.insert(Activity(message: message, isError: isError), at: 0)
        if activity.count > 100 { activity.removeLast(activity.count - 100) }
    }
}
