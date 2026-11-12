import SwiftUI

struct PayloadListView: View {
    @ObservedObject var model: AppModel
    @Environment(\.joyConAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var listIsFocused: Bool
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Picker("Ansicht", selection: $model.section) {
                    Text("Alle").tag(Optional(LibrarySection.all))
                    Text("Favoriten").tag(Optional(LibrarySection.favorites))
                }.pickerStyle(.segmented).labelsHidden().frame(width: 145)
                TextField("Suchen", text: $model.search)
                    .textFieldStyle(.roundedBorder).accessibilityLabel("Payload suchen")
            }.padding(.horizontal, 10).padding(.top, 7)

            if model.filteredPayloads.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: model.section == .favorites ? "star" : "tray.and.arrow.down")
                        .font(.system(size: 25, weight: .light)).foregroundStyle(.secondary)
                    Text(model.search.isEmpty ? (model.section == .favorites ? "Keine Favoriten" : "Keine Payloads") : "Keine Treffer")
                        .font(.callout.weight(.medium))
                    Text(model.section == .favorites ? "Payloads mit dem Stern markieren." : ".bin-Dateien hier ablegen oder hinzufügen.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Hinzufügen…") { model.chooseFiles() }.disabled(model.isSending)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                List {
                    ForEach(model.filteredPayloads) { payload in
                        HStack(spacing: 10) {
                            Image(systemName: "doc.zipper").foregroundStyle(.secondary)
                            Text(payload.name).font(.callout.weight(.medium)).lineLimit(1)
                                .help(payload.filename)
                            Spacer(minLength: 0)
                            Text(ByteCountFormatter.string(fromByteCount: Int64(payload.byteCount), countStyle: .file))
                                .font(.caption).foregroundStyle(.secondary)
                            Button { model.toggleFavorite(payload) } label: {
                                Image(systemName: payload.isFavorite ? "star.fill" : "star")
                                    .foregroundStyle(payload.isFavorite ? accent.controlColor(for: colorScheme) : .secondary)
                            }.buttonStyle(.borderless)
                                .help(payload.isFavorite ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen")
                            Button { model.send(payload) } label: {
                                Image(systemName: "paperplane")
                            }.buttonStyle(.borderless).disabled(!model.canSendToDevice)
                                .help("\(payload.name) senden")
                        }.padding(.vertical, 1).id(payload.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.selectedPayloadID = payload.id
                            listIsFocused = true
                        }
                        .listRowBackground(RoundedRectangle(cornerRadius: 5)
                            .fill(accent.color.opacity(model.selectedPayloadID == payload.id ? 0.2 : 0)))
                        .accessibilityAddTraits(model.selectedPayloadID == payload.id ? .isSelected : [])
                        .accessibilityAction { model.selectedPayloadID = payload.id }
                        .contextMenu {
                            Button("Payload senden") { model.send(payload) }.disabled(!model.canSendToDevice)
                            Button(payload.isFavorite ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen") {
                                model.toggleFavorite(payload)
                            }
                            Button("Im Finder zeigen") { model.reveal(payload) }
                            Divider()
                            Button("Aus Mediathek entfernen", role: .destructive) { model.remove(payload) }
                        }
                    }
                }.listStyle(.inset).disabled(model.isSending)
                    .focusable().focused($listIsFocused)
                    .onMoveCommand { direction in moveSelection(direction) }
                    .onChange(of: model.selectedPayloadID) { _, id in
                        if let id { proxy.scrollTo(id) }
                    }
                }
            }
        }.frame(maxHeight: .infinity)
        .onChange(of: model.filteredPayloads.map(\.id)) { _, ids in
            if !ids.contains(where: { $0 == model.selectedPayloadID }) {
                model.selectedPayloadID = ids.first
            }
        }
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !model.isSending, direction == .up || direction == .down else { return }
        let ids = model.filteredPayloads.map(\.id)
        guard !ids.isEmpty else { return }
        let current = ids.firstIndex { $0 == model.selectedPayloadID }
        let next = current.map { $0 + (direction == .down ? 1 : -1) } ?? (direction == .down ? 0 : ids.count - 1)
        model.selectedPayloadID = ids[min(max(next, 0), ids.count - 1)]
    }
}
