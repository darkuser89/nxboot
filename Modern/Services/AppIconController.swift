import AppKit

@MainActor
final class AppIconController {
    static let shared = AppIconController()
    private let renderer = AppIconRenderer(iconURL: Bundle.main.url(forResource: "AppIconTemplate", withExtension: "png"))

    func apply(_ accent: JoyConAccent) async -> String? {
        // Coalesce rapid palette clicks before rendering and signing an exchange bundle.
        do { try await Task.sleep(for: .milliseconds(180)) } catch { return nil }
        guard let image = await renderer.render(accent), !Task.isCancelled else { return nil }
        let icon = NSImage(cgImage: image, size: NSSize(width: 512, height: 512))
        NSApp.applicationIconImage = icon
        do {
            try await FinderIconService.shared.apply(image, accent: accent, to: Bundle.main.bundleURL)
            return nil
        } catch is CancellationError {
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
