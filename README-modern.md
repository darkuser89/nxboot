# NXBoot Modern für Apple Silicon

Native macOS-Oberfläche auf Basis von [mologie/nxboot](https://github.com/mologie/nxboot).
Die ursprünglichen iOS- und Kommandozeilenprojekte bleiben im Repository erhalten.
Die neue App wird über `Package.swift` gebaut und benötigt macOS 14 oder neuer sowie
einen Apple-Silicon-Mac. Keine externen Swift-Pakete, kein Homebrew und kein Rosetta nötig.

## Verwendung

1. `NXBoot Modern.app` öffnen.
2. Eine eigene `.bin`-Datei über **+**, **⌘O** oder Drag & Drop hinzufügen.
   Neue Dateien erscheinen automatisch in den Favoriten; der Stern schaltet das um.
3. Eine kompatible Konsole im RCM-Modus mit einem USB-Datenkabel verbinden.
4. Payload auswählen und **Senden** oder **⌘↵** verwenden.
   Bei mehreren RCM-Geräten das Ziel ausdrücklich auswählen.

Das kompakte Hauptfenster startet mit 420 × 300 Punkten. **Alle / Favoriten** schaltet
die Liste um; das Papierflieger-Symbol pro Zeile sendet den jeweiligen Payload direkt.
Die Suche filtert Namen und Dateinamen. Unter **…** lassen sich Namen ändern,
Dateien neu zuordnen und Einträge entfernen. Originaldateien werden nicht kopiert oder gelöscht.
Die Mediathek liegt unter `~/Library/Application Support/NXBootModern/library.json`.
Aktivität und Hilfe sind über die Symbole oben erreichbar. Die Aktivitätsliste
ist auf die laufende Sitzung und 100 Einträge begrenzt.

Über das Paletten-Symbol oben lässt sich der Akzent passend zu den Joy-Con-Farben
wählen: Grau, Neongelb, Neongrün, Neonrot, Blau, Lila, Orange, Neonblau und Neonpink.
Die Auswahl bleibt gespeichert und gilt für Buttons, Favoriten, RCM-Anzeige und
die markierte Payload-Zeile. Grau bleibt die Voreinstellung. Im hellen Modus
verwenden kleine Bedienelemente eine dunklere Farbabstufung für bessere Lesbarkeit.
Auch die beiden Joy-Cons im Dock- und Finder-Icon folgen der gewählten Farbe,
einschließlich Grau. Die gespeicherte Auswahl wird beim nächsten Start wiederhergestellt.
Für das Finder-Icon wird eine normale `.icns`-Ressource eingebettet. Eine kurzlebige
Austauschfassung wird lokal ad hoc signiert und mit strenger, rekursiver
Signaturprüfung kontrolliert, bevor sie das aktuelle App-Paket atomar ersetzt.
Die laufende Programmdatei wird dabei nicht überschrieben. Es bleiben nur die
aktuelle App und das aktuelle Farb-Icon erhalten; die Bildvorlage bleibt separat
im Paket erhalten, damit auch ein Wechsel von Grau zurück zu einer Neonfarbe klappt.

Dafür müssen die App und ihr übergeordneter Ordner beschreibbar sein. Diese
Funktion ist für die lokale ad hoc signierte Ausgabe vorgesehen; eine vorhandene
Developer-ID-Signatur wird nicht durch eine ad hoc Signatur ersetzt. Ein bereits
gesetztes Finder-Symbol aus der alten Version wird beim ersten Wechsel migriert.
Bei Fehlern vor dem Austausch bleibt die vorhandene App erhalten. Nach dem Wechsel
gilt wieder `codesign --verify --deep --strict` ohne Ausnahme für Finder-Metadaten.

## USB-Status und Grenzen

- **RCM erkannt:** USB-Kennung `0955:7321` (NVIDIA Tegra RCM/APX).
- **Konsole verbunden · kein RCM:** bekannte Konsolen-Kennung `057E:2000`.
  Andere USB-Geräte und Controller zählen nicht als Konsole.
- **Keine Konsole erkannt:** keine dieser Kennungen sichtbar. Der normale Konsolenbetrieb
  muss sich nicht als USB-Gerät melden; „nicht erkannt“ beweist daher keine fehlende Kabelverbindung.
- **USB-Erkennung nicht verfügbar:** Fehler beim Lesen der Geräteliste.

IOKit meldet das Verbinden und Trennen der unterstützten USB-Geräte direkt.
Die Liste wird beim Start und bei diesen Ereignissen geprüft; im gesunden
Leerlauf läuft kein Abfragetimer. Nur wenn Ereignismeldungen nicht eingerichtet
werden können oder eine Abfrage fehlschlägt, gibt es zeitgesteuerte Wiederholungen.
Die Erkennung öffnet oder beansprucht keine USB-Geräte.
Erst beim Senden öffnet die App das konkrete ausgewählte Gerät und prüft
dessen USB-Identität erneut. Für automatischen Versand einen Payload im Feld neben
**Automatisch** auswählen und den Schalter einschalten. Voreinstellung: aus.
Auswahl und Schalter werden mit der Mediathek gespeichert. Die Automatik gilt für
die nächste erkannte RCM-Verbindung und auch für die Erkennung beim App-Start.
Ein bereits erkanntes Gerät wird durch Einschalten des Schalters nicht sofort gestartet.
Pro Verbindung gibt es höchstens einen automatischen Versuch, auch bei Fehlern.
Bei mehreren RCM-Geräten erfolgt kein automatischer Versand; bitte manuell wählen.
Beim Entfernen des gewählten Payloads wird die Automatik abgeschaltet.
Dateigröße und Erreichbarkeit werden vor dem Senden erneut geprüft.

Unterstützt sind Fusée-`.bin`-Payloads bis **183.640 Bytes**. Der vorhandene
`Shared/intermezzo.bin` wird als Relocator eingebettet. Die neue Oberfläche bietet
keine benutzerdefinierten ShofEL2-Relocatoren oder erweiterten Hekate-Bootparameter.
Es werden keine Boot-Payloads mitgeliefert oder heruntergeladen.

RCM-Erkennung bestätigt keine ungepatchte Hardware. Gepatchte Switch-Modelle,
Switch Lite und OLED werden durch diese App nicht Fusée-kompatibel.
**Start angefordert** bedeutet: der USB-Transfer ist abgeschlossen und der
Startrequest wurde ausgelöst. Ein erfolgreicher Start auf der Konsole ist damit
nicht nachgewiesen. Nach einem USB-Sendeversuch muss die verbrauchte RCM-Sitzung
vor erneutem Senden getrennt und neu aufgebaut werden.

## Bauen und starten

### GitHub baut und veröffentlicht

Der Workflow `.github/workflows/macos.yml` baut auf einem GitHub-gehosteten
Apple-Silicon-Mac. Änderungen auf `master` und manuelle Workflow-Starts führen
die Tests, den Release-Build und die Finder-Farb-/Signaturprüfungen aus.
Erst danach erstellt GitHub Actions das Release `v<VERSION>` mit ARM-App-ZIP
und SHA-256-Prüfsumme. Pull Requests prüfen nur und veröffentlichen nichts.
Eine bestehende Veröffentlichung wird nicht überschrieben; für die nächste
Veröffentlichung zuerst `VERSION` erhöhen. Fertige lokale Apps oder Buildbäume
werden nicht ins Repository übertragen. Es werden keine Apple-Zertifikate benötigt;
die Ausgabe ist ad hoc signiert und nicht notarisiert.

### Lokale Entwicklung

Xcode mit macOS-SDK installieren; dann im Projektordner:

```sh
./script/build_and_run.sh             # bauen und öffnen
./script/build_and_run.sh --verify    # zusätzlich laufenden Prozess prüfen
./script/build_and_run.sh --build-only
./script/test.sh                     # Unit-Tests, USB-Senden ausschließlich simuliert
./script/check_finder_icons.sh       # Integration: alle Farben, Migration und strenge Signaturen; kein USB
```

Optional: `--debug` oder `--logs`. Die Codex-Run-Aktion ruft denselben Buildstart auf.
Alternativ `Package.swift` in Xcode öffnen und das Produkt `NXBootModern` untersuchen;
für eine vollständige App einschließlich Relocator das Skript verwenden.

Der einzige aktuelle Buildbaum liegt standardmäßig neben dem Quellordner unter
`../NXBootModern-Build`; dort liegt auch `NXBoot Modern.app`. Mit `NXBOOT_BUILD_ROOT`
kann ein anderer absoluter Pfad außerhalb von Code und Audit festgelegt werden.
Builds, Modulcache und die App bleiben damit vom Quellcode getrennt.
Die App wird lokal ad hoc signiert; sie ist nicht für eine öffentliche Verteilung notarisiert.
`NXBOOT_CONFIGURATION=release` wählt einen optimierten Build; standardmäßig wird
für die lokale Entwicklung `debug` verwendet. Die App-Version stammt aus `VERSION`.

## Aufbau

- `Modern/`: SwiftUI-App, Mediathek, Dateilesezeichen und Oberflächenzustand.
- `Assets/AppIcon.png`: Icon-Master mit zwei Joy-Cons. Der Build erzeugt daraus
  die macOS- und Retina-Auflösungen im eingebetteten `AppIcon.icns`.
- `ModernUSB/`: eng begrenzte Objective-C-Brücke für Scan und gezielten Versand.
- `NXBootKit/`: bestehender nxboot-Injektor. Korrekturen für USB-Ressourcenfreigabe,
  fehlende Bulk-Endpunkte und die auf USB-Pakete abgestimmte Größenbegrenzung.
- `Tests/`: Dateigrenzen, Persistenz, Favoriten, USB-Kennungen, Verbindungswechsel,
  explizite Zielwahl und Schutz gegen wiederholtes Senden derselben RCM-Sitzung.

## Lizenz

GPLv3 wie das Original, siehe `COPYING.md`. NXBoot und der USB-Injektor stammen
von Oliver Kuckertz und den im ursprünglichen README genannten Mitwirkenden.
