import SwiftUI

enum JoyConAccent: String, CaseIterable, Identifiable {
    case gray, yellow, green, red, blue, purple, orange, cyan, pink
    var id: String { rawValue }

    var name: String {
        switch self {
        case .gray: return "Grau"
        case .yellow: return "Neongelb"
        case .green: return "Neongrün"
        case .red: return "Neonrot"
        case .blue: return "Blau"
        case .purple: return "Lila"
        case .orange: return "Orange"
        case .cyan: return "Neonblau"
        case .pink: return "Neonpink"
        }
    }

    // Representative surface colors sampled from the user's Joy-Con reference.
    private var hex: UInt32 {
        switch self {
        case .gray: return 0x70777C
        case .yellow: return 0xD4F156
        case .green: return 0x00E14F
        case .red: return 0xFF5D51
        case .blue: return 0x4759BD
        case .purple: return 0x902FAC
        case .orange: return 0xF6B22B
        case .cyan: return 0x00BCDF
        case .pink: return 0xFF4A84
        }
    }
    var rgb: (Double, Double, Double) {
        (Double((hex >> 16) & 255) / 255, Double((hex >> 8) & 255) / 255, Double(hex & 255) / 255)
    }
    var color: Color {
        let (r, g, b) = rgb
        return Color(red: r, green: g, blue: b)
    }
    var onColor: Color {
        let (r, g, b) = rgb
        let luminance = Self.luminance(r, g, b)
        return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05) ? .black : .white
    }
    func controlColor(for scheme: ColorScheme) -> Color {
        let (r, g, b) = rgb
        // Bright neon text needs a darker shade against light system surfaces.
        var factor = 1.0
        if scheme == .light {
            while Self.luminance(r * factor, g * factor, b * factor) > 0.18 { factor *= 0.95 }
        }
        return Color(red: r * factor, green: g * factor, blue: b * factor)
    }
    private static func luminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}

private struct JoyConAccentKey: EnvironmentKey {
    static let defaultValue = JoyConAccent.gray
}

extension EnvironmentValues {
    var joyConAccent: JoyConAccent {
        get { self[JoyConAccentKey.self] }
        set { self[JoyConAccentKey.self] = newValue }
    }
}
