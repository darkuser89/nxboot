import SwiftUI

struct ConnectionView: View {
    @ObservedObject var model: AppModel
    @Environment(\.joyConAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    private var color: Color {
        if model.usbError != nil { return .red }
        return model.rcmDevices.isEmpty ? .secondary : accent.controlColor(for: colorScheme)
    }
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle().fill(color).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.statusTitle.localized(in: language)).font(.callout.weight(.semibold))
                }
                Spacer(minLength: 6)
                if model.isSending { ProgressView().controlSize(.small) }
                else {
                    Button { Task { await model.refresh() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }.buttonStyle(.borderless).help(language.text("usb.refreshHelp"))
                }
            }
            if model.rcmDevices.count > 1 {
                Picker(language.text("usb.target"), selection: $model.selectedDeviceID) {
                    Text(language.text("usb.choose")).tag(Optional<UInt64>.none)
                    ForEach(model.rcmDevices) { device in
                        Text(device.identity).tag(Optional(device.id))
                    }
                }.controlSize(.small).disabled(model.isSending)
            }
        }.padding(.horizontal, 12).padding(.vertical, 9)
        .help(model.statusDetail.localized(in: language) + (model.selectedDevice.map { "\n" + $0.identity } ?? ""))
    }
}
