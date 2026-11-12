import SwiftUI

struct AutomaticSendView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Toggle("Automatisch", isOn: Binding(
                get: { model.automaticEnabled },
                set: { model.configureAutomatic(payloadID: model.automaticPayloadID, enabled: $0) }
            ))
            .toggleStyle(.checkbox)
            .disabled(model.automaticPayload == nil)
            Picker("Automatischer Payload", selection: Binding(
                get: { model.automaticPayloadID },
                set: { model.configureAutomatic(payloadID: $0, enabled: model.automaticEnabled) }
            )) {
                Text("Payload wählen…").tag(Optional<UUID>.none)
                ForEach(model.payloads) { payload in
                    Text(payload.name).tag(Optional(payload.id))
                }
            }.labelsHidden().frame(maxWidth: .infinity)
        }
        .font(.caption)
        .disabled(model.isSending)
        .padding(.horizontal, 12).padding(.bottom, 8)
        .help("Bei der nächsten RCM-Erkennung einmal senden. Bei mehreren RCM-Geräten bitte manuell wählen.")
    }
}
