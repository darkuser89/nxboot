import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var showsHelp = false
    @State private var showsActivity = false
    @State private var showsAccentPicker = false
    @AppStorage("joyConAccent") private var accent = JoyConAccent.gray
    @Environment(\.colorScheme) private var colorScheme

    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(spacing: 0) {
            ConnectionView(model: model)
            AutomaticSendView(model: model)
            Divider()
            PayloadListView(model: model)
            Divider()
            PayloadDetailView(model: model)
        }
        .frame(minWidth: 380, minHeight: 220)
        .controlSize(.small)
        .tint(accent.controlColor(for: colorScheme))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showsAccentPicker.toggle() } label: {
                    Label(language.text("accent.title"), systemImage: "paintpalette")
                }.help(language.text("accent.choose", accent.name(in: language)))
                    .popover(isPresented: $showsAccentPicker) { AccentPickerView(selection: $accent) }
                Button { model.chooseFiles(language: language) } label: {
                    Label(language.text("payload.add"), systemImage: "plus")
                }.help(language.text("payload.addHelp")).disabled(model.isSending)
                Button { showsActivity = true } label: {
                    Label(language.text("activity.title"), systemImage: "clock.arrow.circlepath")
                }.help(language.text("activity.title"))
                Button { showsHelp = true } label: {
                    Label(language.text("help.title"), systemImage: "questionmark.circle")
                }.help(language.text("help.title"))
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !model.isSending else { return false }
            model.importFiles(urls)
            return true
        }
        .alert("NXBoot Modern", isPresented: Binding(
            get: { model.error != nil }, set: { if !$0 { model.error = nil } }
        )) {
            Button(language.text("action.ok"), role: .cancel) { model.error = nil }
        } message: { Text(model.error?.localized(in: language) ?? "") }
        .sheet(isPresented: $showsHelp) { HelpView() }
        .sheet(isPresented: $showsActivity) {
            VStack(spacing: 0) {
                ActivityView(entries: model.activity)
                HStack {
                    Spacer()
                    Button(language.text("action.done")) { showsActivity = false }.keyboardShortcut(.defaultAction)
                }.padding(16)
            }.frame(width: 580, height: 380)
        }
        .environment(\.joyConAccent, accent)
        .task(id: accent) {
            if let message = await AppIconController.shared.apply(accent) { model.error = message }
        }
    }
}
