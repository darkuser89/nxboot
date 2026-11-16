import XCTest
@testable import NXBootModern

final class AppLanguageTests: XCTestCase {
    func testSystemLanguageAndManualOverride() {
        XCTAssertEqual(LanguagePreference.system.resolve(preferredLanguage: "de-AT"), .de)
        XCTAssertEqual(LanguagePreference.system.resolve(preferredLanguage: "ro-MD"), .ro)
        XCTAssertEqual(LanguagePreference.system.resolve(preferredLanguage: "en-GB"), .en)
        XCTAssertEqual(LanguagePreference.system.resolve(preferredLanguage: "fr-FR"), .en)
        XCTAssertEqual(LanguagePreference.system.resolve(preferredLanguage: nil), .en)
        XCTAssertEqual(LanguagePreference.ro.resolve(preferredLanguage: "de-DE"), .ro)
        XCTAssertEqual(LanguagePreference.de.resolve(preferredLanguage: "en-US"), .de)
        XCTAssertEqual(LanguagePreference.en.resolve(preferredLanguage: "ro-RO"), .en)
    }

    func testLocalizedMessagesAndUSBError() {
        let entry = AppMessage("activity.sending", "Hekate", "USB 01")
        XCTAssertEqual(entry.localized(in: .en), "Sending Hekate to USB 01…")
        XCTAssertEqual(entry.localized(in: .de), "Sende Hekate an USB 01…")
        XCTAssertEqual(entry.localized(in: .ro), "Se trimite Hekate către USB 01…")
        let usbError = NSError(domain: "NXBootModern.USB", code: 3,
                               userInfo: ["NXBootMessageKey": "error.usbDisconnected"])
        XCTAssertEqual(AppMessage(error: usbError).localized(in: .ro),
                       "Dispozitivul USB selectat a fost deconectat.")
    }
}
