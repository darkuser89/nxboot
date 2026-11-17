import SwiftUI

struct LanguageSettingsView: View {
    @Binding var preference: LanguagePreference
    @Environment(\.appLanguage) private var language

    private var needsRestart: Bool { language != AppLanguage.startupLanguage }

    var body: some View {
        Form {
            Picker(language.text("language.title"), selection: $preference) {
                ForEach(LanguagePreference.allCases) { option in
                    Text(option.title(in: language)).tag(option)
                }
            }
            if preference == .system {
                Text(language.text("language.active", LanguagePreference(rawValue: language.rawValue)?.title(in: language) ?? "English"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if needsRestart {
                Text(language.text("language.restart"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(width: 350, height: needsRestart && preference == .system ? 138 : 106)
    }
}
