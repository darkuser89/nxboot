import AppKit
import SwiftUI

@main
struct NXBootModernApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("NXBoot Modern", id: "main") {
            ContentView(model: model)
                .task { await model.monitor() }
        }
        .defaultSize(width: 420, height: 300)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Payloads hinzufügen…") { model.chooseFiles() }
                    .keyboardShortcut("o")
                    .disabled(model.isSending)
            }
            CommandMenu("Payload") {
                Button("Ausgewählten Payload senden") { model.send() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.canSend)
                if let payload = model.selectedPayload {
                    Button(payload.isFavorite ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen") {
                        model.toggleFavorite(payload)
                    }.keyboardShortcut("d")
                }
                Divider()
                Button("USB-Status aktualisieren") { Task { await model.refresh() } }
                    .keyboardShortcut("r")
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Apply the compact layout once, including to an earlier restored large window.
        DispatchQueue.main.async {
            guard UserDefaults.standard.integer(forKey: "windowLayoutVersion") < 2,
                  let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }
            window.setContentSize(NSSize(width: 420, height: 300))
            window.center()
            UserDefaults.standard.set(2, forKey: "windowLayoutVersion")
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
