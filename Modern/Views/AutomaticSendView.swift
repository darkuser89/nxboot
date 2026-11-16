import SwiftUI

struct AutomaticSendView: View {
    @ObservedObject var model: AppModel

    @Environment(\.appLanguage) private var language

    var body: some View {
        HStack(spacing: 10) {
            Toggle(language.text("auto.title"), isOn: Binding(
                get: { model.automaticEnabled },
                set: { model.configureAutomatic(payloadID: model.automaticPayloadID, enabled: $0) }
            ))
            .toggleStyle(.checkbox)
            .disabled(model.automaticPayload == nil)
            Picker(language.text("auto.payload"), selection: Binding(
                get: { model.automaticPayloadID },
                set: { model.configureAutomatic(payloadID: $0, enabled: model.automaticEnabled) }
            )) {
                Text(language.text("payload.choose")).tag(Optional<UUID>.none)
                ForEach(model.payloads) { payload in
                    Text(payload.name).tag(Optional(payload.id))
                }
            }.labelsHidden().frame(maxWidth: .infinity)
        }
        .font(.caption)
        .disabled(model.isSending)
        .padding(.horizontal, 12).padding(.bottom, 8)
        .help(language.text("auto.help"))
    }
}
