import SwiftUI

struct ActivityView: View {
    let entries: [Activity]
    @Environment(\.joyConAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(language.text("activity.session")).font(.title2.weight(.semibold))
            Text(language.text("activity.limit"))
                .font(.callout).foregroundStyle(.secondary)
            if entries.isEmpty {
                ContentUnavailableView(language.text("activity.empty"), systemImage: "clock",
                                       description: Text(language.text("activity.placeholder")))
            } else {
                List(entries) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.isError ? "exclamationmark.circle" : "circle.fill")
                            .font(.system(size: entry.isError ? 14 : 6))
                            .foregroundStyle(entry.isError ? .red : accent.controlColor(for: colorScheme)).frame(width: 16, height: 17)
                        Text(entry.message.localized(in: language)).textSelection(.enabled)
                        Spacer()
                        Text(entry.date, style: .time).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }.listStyle(.plain)
            }
        }.padding(26).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
