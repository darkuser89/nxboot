import SwiftUI

struct PayloadListView: View {
    @ObservedObject var model: AppModel
    @Environment(\.joyConAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var listIsFocused: Bool
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Picker(language.text("payload.view"), selection: $model.section) {
                    Text(language.text("payload.all")).tag(Optional(LibrarySection.all))
                    Text(language.text("favorites.title")).tag(Optional(LibrarySection.favorites))
                }.pickerStyle(.segmented).labelsHidden().frame(width: 145)
                TextField(language.text("payload.search"), text: $model.search)
                    .textFieldStyle(.roundedBorder).accessibilityLabel(language.text("payload.searchHelp"))
            }.padding(.horizontal, 10).padding(.top, 7)

            if model.filteredPayloads.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: model.section == .favorites ? "star" : "tray.and.arrow.down")
                        .font(.system(size: 25, weight: .light)).foregroundStyle(.secondary)
                    Text(language.text(model.search.isEmpty ? (model.section == .favorites ? "favorites.empty" : "payload.noFiles") : "payload.noResults"))
                        .font(.callout.weight(.medium))
                    Text(language.text(model.section == .favorites ? "favorites.hint" : "payload.dropHint"))
                        .font(.caption).foregroundStyle(.secondary)
                    Button(language.text("action.add")) { model.chooseFiles(language: language) }.disabled(model.isSending)
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
                            Text(Int64(payload.byteCount).formatted(.byteCount(style: .file).locale(language.locale)))
                                .font(.caption).foregroundStyle(.secondary)
                            Button { model.toggleFavorite(payload) } label: {
                                Image(systemName: payload.isFavorite ? "star.fill" : "star")
                                    .foregroundStyle(payload.isFavorite ? accent.controlColor(for: colorScheme) : .secondary)
                            }.buttonStyle(.borderless)
                                .help(language.text(payload.isFavorite ? "favorites.remove" : "favorites.add"))
                            Button { model.send(payload) } label: {
                                Image(systemName: "paperplane")
                            }.buttonStyle(.borderless).disabled(!model.canSendToDevice)
                                .help(language.text("payload.sendNamed", payload.name))
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
                            Button(language.text("payload.sendMenu")) { model.send(payload) }.disabled(!model.canSendToDevice)
                            Button(language.text(payload.isFavorite ? "favorites.remove" : "favorites.add")) {
                                model.toggleFavorite(payload)
                            }
                            Button(language.text("payload.showInFinder")) { model.reveal(payload) }
                            Divider()
                            Button(language.text("payload.remove"), role: .destructive) { model.remove(payload) }
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
