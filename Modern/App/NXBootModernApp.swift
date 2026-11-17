import AppKit
import SwiftUI

@main
struct NXBootModernApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()
    @AppStorage(LanguagePreference.storageKey) private var languagePreference = LanguagePreference.system

    init() {
        AppLanguage.startupLanguage.applyToNativeInterface()
    }

    private var language: AppLanguage { languagePreference.resolve() }

    var body: some Scene {
        Window("NXBoot Modern", id: "main") {
            ContentView(model: model)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
                .task { await model.monitor() }
        }
        .defaultSize(width: 420, height: 300)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(language.text("payload.addMultiple")) { model.chooseFiles(language: language) }
                    .keyboardShortcut("o")
                    .disabled(model.isSending)
            }
            CommandMenu("Payload") {
                Button(language.text("payload.sendSelected")) { model.send() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.canSend)
                if let payload = model.selectedPayload {
                    Button(language.text(payload.isFavorite ? "favorites.remove" : "favorites.add")) {
                        model.toggleFavorite(payload)
                    }.keyboardShortcut("d")
                }
                Divider()
                Button(language.text("usb.refresh")) { Task { await model.refresh() } }
                    .keyboardShortcut("r")
            }
        }
        Settings {
            LanguageSettingsView(preference: $languagePreference)
                .environment(\.appLanguage, language)
                .environment(\.locale, language.locale)
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
