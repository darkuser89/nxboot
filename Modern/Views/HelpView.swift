import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.joyConAccent) private var accent
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "cable.connector").font(.largeTitle).foregroundStyle(accent.controlColor(for: colorScheme))
                Text("Verbinden. Auswählen. Senden.").font(.title2.weight(.bold))
            }
            Text("1. Konsole im RCM-Modus per USB-Datenkabel verbinden.\n2. Eigene .bin-Datei hinzufügen und mit dem Stern markieren.\n3. Bei ‚RCM erkannt‘ auf Senden klicken (⌘↵).")
                .lineSpacing(8)
            Divider()
            Text("Automatisch senden").font(.headline)
            Text("Payload im Auswahlfeld wählen, dann ‚Automatisch‘ einschalten. Ab der nächsten erkannten RCM-Verbindung wird dieser Payload einmal gesendet. Die Einstellung bleibt gespeichert und gilt auch beim nächsten App-Start. Bei mehreren RCM-Geräten bitte manuell senden.")
                .font(.callout).foregroundStyle(.secondary)
            Text("Was der Status bedeutet").font(.headline)
            Text("RCM: USB-Kennung 0955:7321.\nKein RCM: bekannte Konsolen-Kennung 057E:2000.\nKeine Konsole erkannt: keine dieser Kennungen sichtbar. Eine eingeschaltete Konsole muss sich nicht als USB-Gerät melden.")
                .font(.callout).foregroundStyle(.secondary).lineSpacing(5)
            Text("Nur ungepatchte, kompatible Tegra-X1-Geräte unterstützen diesen Startweg. RCM allein bestätigt das nicht. ‚Start angefordert‘ bestätigt die Übertragung, nicht den erfolgreichen Start auf der Konsole.")
                .font(.callout).foregroundStyle(.secondary)
            Text("Favoriten speichern Verweise auf deine Dateien. Nach Verschieben oder Löschen bei Bedarf ‚Datei neu zuordnen‘ verwenden. Entfernen aus der Mediathek löscht die Originaldatei nicht.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Link("Basis: mologie/nxboot · GPLv3", destination: URL(string: "https://github.com/mologie/nxboot")!)
                Spacer()
                Button("Fertig") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 520)
    }
}
