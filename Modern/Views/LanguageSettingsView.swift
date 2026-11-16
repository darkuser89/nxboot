import SwiftUI

struct LanguageSettingsView: View {
    @Binding var preference: LanguagePreference
    @Environment(\.appLanguage) private var language

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
        }
        .padding(20)
        .frame(width: 350, height: 106)
    }
}
