import Foundation

struct USBDevice: Identifiable, Equatable, Sendable {
    let id: UInt64
    let location: UInt32
    let vendor: UInt16
    let product: UInt16
    let name: String
    var isRCM: Bool { vendor == 0x0955 && product == 0x7321 }
    var identity: String { String(format: "%04X:%04X · USB %08X", vendor, product, location) }
    var title: String { isRCM ? "Tegra RCM" : "Nintendo Switch · kein RCM" }
}

struct Activity: Identifiable {
    let id = UUID()
    let date = Date()
    let message: String
    let isError: Bool
}

enum LibrarySection: String, CaseIterable, Identifiable {
    case all = "Alle Payloads", favorites = "Favoriten", activity = "Aktivität"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .all: return "square.stack.3d.up"
        case .favorites: return "star"
        case .activity: return "clock.arrow.circlepath"
        }
    }
}
