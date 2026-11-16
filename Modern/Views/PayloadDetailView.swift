import SwiftUI

struct PayloadDetailView: View {
    @ObservedObject var model: AppModel
    @Environment(\.joyConAccent) private var accent
    @State private var renaming = false
    @State private var newName = ""
    @State private var renameID: UUID?

    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.selectedPayload?.name ?? language.text("payload.select"))
                        .font(.callout.weight(.medium)).lineLimit(1)

                }
                .help(model.selectedPayload?.lastSentAt.map {
                    language.text("payload.lastSent", $0.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(language.locale)))
                } ?? language.text("payload.neverSent"))
                Spacer(minLength: 0)
                if let payload = model.selectedPayload {
                    Menu {
                        Button(language.text("payload.rename")) {
                            newName = payload.name; renameID = payload.id; renaming = true
                        }
                        Button(language.text("payload.relink")) { model.chooseFiles(replacing: payload.id, language: language) }
                        Button(language.text("payload.showInFinder")) { model.reveal(payload) }
                        Divider()
                        Button(language.text("payload.remove"), role: .destructive) { model.remove(payload) }
                    } label: {
                        Image(systemName: "ellipsis")
                    }.menuStyle(.borderlessButton).fixedSize().disabled(model.isSending)
                        .help(language.text("payload.manage"))
                }
                Button { model.send() } label: {
                    Label(language.text(model.isSending ? "payload.sending" : "payload.send"), systemImage: "paperplane.fill")
                }.buttonStyle(.borderedProminent)
                    .tint(accent.color).foregroundStyle(model.canSend ? accent.onColor : .secondary)
                    .disabled(!model.canSend).help(language.text("payload.sendHelp"))
            }
            if let result = model.lastResult {
                Text(result.localized(in: language)).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).help(result.localized(in: language))
            }
        }.padding(10)
        .alert(language.text("payload.renameTitle"), isPresented: $renaming) {
            TextField(language.text("action.name"), text: $newName)
            Button(language.text("action.cancel"), role: .cancel) {}
            Button(language.text("action.save")) {
                if let payload = model.payloads.first(where: { $0.id == renameID }) {
                    model.rename(payload, to: newName)
                }
            }
        }
    }
}
