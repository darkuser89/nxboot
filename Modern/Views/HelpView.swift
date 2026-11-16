import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.joyConAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "cable.connector").font(.largeTitle).foregroundStyle(accent.controlColor(for: colorScheme))
                Text(language.text("help.heading")).font(.title2.weight(.bold))
            }
            Text(language.text("help.steps"))
                .lineSpacing(8)
            Divider()
            Text(language.text("auto.heading")).font(.headline)
            Text(language.text("help.automatic"))
                .font(.callout).foregroundStyle(.secondary)
            Text(language.text("help.status")).font(.headline)
            Text(language.text("help.devices"))
                .font(.callout).foregroundStyle(.secondary).lineSpacing(5)
            Text(language.text("help.compatibility"))
                .font(.callout).foregroundStyle(.secondary)
            Text(language.text("help.favorites"))
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Link(language.text("help.source"), destination: URL(string: "https://github.com/mologie/nxboot")!)
                Spacer()
                Button(language.text("action.done")) { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 520)
    }
}
