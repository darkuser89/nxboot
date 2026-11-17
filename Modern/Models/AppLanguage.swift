import Foundation
import SwiftUI

enum LanguagePreference: String, CaseIterable, Identifiable {
    case system, en, de, ro

    static let storageKey = "languagePreference"

    var id: String { rawValue }

    func resolve(preferredLanguage: String? = AppLanguage.systemIdentifier) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? AppLanguage.matching(preferredLanguage)
    }

    func title(in language: AppLanguage) -> String {
        switch self {
        case .system: return language.text("language.system")
        case .en: return "English"
        case .de: return "Deutsch"
        case .ro: return "Română"
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case en, de, ro

    // Capture the macOS preference before setting the current process's language.
    static let systemIdentifier: String? = {
        UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? Locale.preferredLanguages.first
    }()

    static let startupLanguage: AppLanguage = {
        let saved = UserDefaults.standard.string(forKey: LanguagePreference.storageKey)
        return (saved.flatMap(LanguagePreference.init(rawValue:)) ?? .system).resolve()
    }()

    func applyToNativeInterface(defaults: UserDefaults = .standard) {
        var launchArguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        launchArguments["AppleLanguages"] = [rawValue]
        defaults.setVolatileDomain(launchArguments, forName: UserDefaults.argumentDomain)
    }

    static func matching(_ identifier: String?) -> AppLanguage {
        guard let identifier, let code = Locale(identifier: identifier).language.languageCode?.identifier else {
            return .en
        }
        return AppLanguage(rawValue: code.lowercased()) ?? .en
    }

    var locale: Locale { Locale(identifier: rawValue) }

    func text(_ key: String, _ arguments: String...) -> String {
        format(key, arguments: arguments)
    }

    fileprivate func format(_ key: String, arguments: [String]) -> String {
        let value = Self.bundles[self]?.localizedString(forKey: key, value: "", table: nil)
        let format = value == nil || value == key
            ? Self.bundles[.en]?.localizedString(forKey: key, value: nil, table: nil) ?? key
            : value ?? key
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments.map { $0 as CVarArg })
    }

    private static let bundles = Dictionary(uniqueKeysWithValues: allCases.compactMap { language in
        let name = language.rawValue
        var url = Bundle.main.url(forResource: name, withExtension: "lproj")
        #if SWIFT_PACKAGE
        if url == nil { url = Bundle.module.url(forResource: name, withExtension: "lproj") }
        #endif
        guard let url, let bundle = Bundle(url: url) else { return nil as (AppLanguage, Bundle)? }
        return (language, bundle)
    })
}

protocol LocalizedAppError: LocalizedError {
    var message: AppMessage { get }
}

extension LocalizedAppError {
    var errorDescription: String? { message.errorDescription }
}

/// Stores translatable messages until presentation, including existing activity entries.
struct AppMessage: LocalizedError, Equatable, Sendable {
    let key: String
    private let arguments: [String]

    init(_ key: String, _ arguments: String...) {
        self.key = key
        self.arguments = arguments
    }

    init(error: Error) {
        if let message = error as? AppMessage { self = message; return }
        if let error = error as? any LocalizedAppError { self = error.message; return }
        let error = error as NSError
        if let key = error.userInfo["NXBootMessageKey"] as? String {
            self.init(key)
        } else {
            self.init("error.details", error.localizedDescription)
        }
    }

    func localized(in language: AppLanguage) -> String { language.format(key, arguments: arguments) }
    var errorDescription: String? { localized(in: .matching(AppLanguage.systemIdentifier)) }
}

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue = AppLanguage.en
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}
