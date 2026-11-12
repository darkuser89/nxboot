import SwiftUI

struct ActivityView: View {
    let entries: [Activity]
    @Environment(\.joyConAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Aktuelle Sitzung").font(.title2.weight(.semibold))
            Text("Verbindungen und Übertragungen dieser Sitzung. Maximal 100 Einträge.")
                .font(.callout).foregroundStyle(.secondary)
            if entries.isEmpty {
                ContentUnavailableView("Noch keine Aktivität", systemImage: "clock",
                                       description: Text("USB-Verbindungen und Sendevorgänge erscheinen hier."))
            } else {
                List(entries) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.isError ? "exclamationmark.circle" : "circle.fill")
                            .font(.system(size: entry.isError ? 14 : 6))
                            .foregroundStyle(entry.isError ? .red : accent.controlColor(for: colorScheme)).frame(width: 16, height: 17)
                        Text(entry.message).textSelection(.enabled)
                        Spacer()
                        Text(entry.date, style: .time).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }.listStyle(.plain)
            }
        }.padding(26).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
