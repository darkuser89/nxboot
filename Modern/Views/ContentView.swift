import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var showsHelp = false
    @State private var showsActivity = false
    @State private var showsAccentPicker = false
    @AppStorage("joyConAccent") private var accent = JoyConAccent.gray
    @Environment(\.colorScheme) private var colorScheme

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
                    Label("Joy-Con-Akzent", systemImage: "paintpalette")
                }.help("Joy-Con-Farbe wählen · \(accent.name)")
                    .popover(isPresented: $showsAccentPicker) { AccentPickerView(selection: $accent) }
                Button { model.chooseFiles() } label: {
                    Label("Payload hinzufügen", systemImage: "plus")
                }.help("Payload hinzufügen (⌘O)").disabled(model.isSending)
                Button { showsActivity = true } label: {
                    Label("Aktivität", systemImage: "clock.arrow.circlepath")
                }.help("Aktivität")
                Button { showsHelp = true } label: {
                    Label("Hilfe", systemImage: "questionmark.circle")
                }.help("Hilfe")
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
            Button("OK", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
        .sheet(isPresented: $showsHelp) { HelpView() }
        .sheet(isPresented: $showsActivity) {
            VStack(spacing: 0) {
                ActivityView(entries: model.activity)
                HStack {
                    Spacer()
                    Button("Fertig") { showsActivity = false }.keyboardShortcut(.defaultAction)
                }.padding(16)
            }.frame(width: 580, height: 380)
        }
        .environment(\.joyConAccent, accent)
        .task(id: accent) {
            if let message = await AppIconController.shared.apply(accent) { model.error = message }
        }
    }
}
