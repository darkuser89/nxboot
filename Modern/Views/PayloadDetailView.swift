import SwiftUI

struct PayloadDetailView: View {
    @ObservedObject var model: AppModel
    @Environment(\.joyConAccent) private var accent
    @State private var renaming = false
    @State private var newName = ""
    @State private var renameID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.selectedPayload?.name ?? "Payload auswählen")
                        .font(.callout.weight(.medium)).lineLimit(1)

                }
                .help(model.selectedPayload?.lastSentAt.map { "Zuletzt: \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Noch nicht gesendet")
                Spacer(minLength: 0)
                if let payload = model.selectedPayload {
                    Menu {
                        Button("Umbenennen…") {
                            newName = payload.name; renameID = payload.id; renaming = true
                        }
                        Button("Datei neu zuordnen…") { model.chooseFiles(replacing: payload.id) }
                        Button("Im Finder zeigen") { model.reveal(payload) }
                        Divider()
                        Button("Aus Mediathek entfernen", role: .destructive) { model.remove(payload) }
                    } label: {
                        Image(systemName: "ellipsis")
                    }.menuStyle(.borderlessButton).fixedSize().disabled(model.isSending)
                        .help("Payload verwalten")
                }
                Button { model.send() } label: {
                    Label(model.isSending ? "Senden…" : "Senden", systemImage: "paperplane.fill")
                }.buttonStyle(.borderedProminent)
                    .tint(accent.color).foregroundStyle(model.canSend ? accent.onColor : .secondary)
                    .disabled(!model.canSend).help("Payload senden (⌘↵)")
            }
            if let result = model.lastResult {
                Text(result).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).help(result)
            }
        }.padding(10)
        .alert("Payload umbenennen", isPresented: $renaming) {
            TextField("Name", text: $newName)
            Button("Abbrechen", role: .cancel) {}
            Button("Speichern") {
                if let payload = model.payloads.first(where: { $0.id == renameID }) {
                    model.rename(payload, to: newName)
                }
            }
        }
    }
}
