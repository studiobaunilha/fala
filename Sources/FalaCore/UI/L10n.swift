import Combine
import Foundation

public enum AppLocalization {
    public static let supportedAppLanguageCodes = ["pt-BR", "en", "es", "fr"]
    public static let languageChangedNotification = Notification.Name("dev.fala.app-language-changed")

    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var overrideLanguageCode = "auto"
        var localizedTables: [String: [String: String]] = [:]
        var fallbackCatalog: [String: [String: String]]?
    }

    private static let state = State()

    public static func apply(languageCode: String) {
        state.lock.lock()
        let didChange = state.overrideLanguageCode != languageCode
        state.overrideLanguageCode = languageCode
        state.lock.unlock()

        if didChange {
            NotificationCenter.default.post(name: languageChangedNotification, object: nil)
            Task { @MainActor in
                AppLocalizationObserver.shared.invalidate()
            }
        }
    }

    public static func currentLocale() -> Locale {
        Locale(identifier: resolvedLanguageCode())
    }

    public static func localizedString(for source: String) -> String {
        localizedString(for: source, languageCode: resolvedLanguageCode())
    }

    public static func localizedString(for source: String, languageCode: String) -> String {
        let resolvedCode = resolveLanguageCode(languageCode)
        guard resolvedCode != "pt-BR" else {
            return source
        }

        let table = compiledLocalizationTable(for: resolvedCode)
        if let localized = table[source], !localized.isEmpty {
            return localized
        }

        let catalog = fallbackCatalogEntries()
        return catalog[source]?[resolvedCode] ?? source
    }

    public static func resolvedLanguageCode() -> String {
        let selectedCode = {
            state.lock.lock()
            defer { state.lock.unlock() }
            return state.overrideLanguageCode
        }()
        return resolveLanguageCode(selectedCode)
    }

    public static func resolveLanguageCode(_ selectedCode: String) -> String {
        let trimmed = selectedCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "auto" {
            return systemPreferredLanguageCode()
        }
        return normalizedSupportedLanguageCode(for: trimmed) ?? "pt-BR"
    }

    private static func systemPreferredLanguageCode() -> String {
        for identifier in Locale.preferredLanguages {
            if let normalized = normalizedSupportedLanguageCode(for: identifier) {
                return normalized
            }
        }
        return "pt-BR"
    }

    private static func normalizedSupportedLanguageCode(for identifier: String) -> String? {
        if supportedAppLanguageCodes.contains(identifier) {
            return identifier
        }

        let lowercased = identifier.lowercased()
        if lowercased.hasPrefix("pt") {
            return "pt-BR"
        }
        if lowercased.hasPrefix("en") {
            return "en"
        }
        if lowercased.hasPrefix("es") {
            return "es"
        }
        if lowercased.hasPrefix("fr") {
            return "fr"
        }
        return nil
    }

    static func compiledLocalizationResourceURL(for languageCode: String) -> URL? {
        let resolvedCode = resolveLanguageCode(languageCode)
        for candidate in localizationCandidates(for: resolvedCode) {
            if let url = Bundle.module.url(
                forResource: "Localizable",
                withExtension: "strings",
                subdirectory: nil,
                localization: candidate
            ) {
                return url
            }
        }
        return nil
    }

    private static func compiledLocalizationTable(for languageCode: String) -> [String: String] {
        state.lock.lock()
        if let cached = state.localizedTables[languageCode] {
            state.lock.unlock()
            return cached
        }
        state.lock.unlock()

        let loaded = loadCompiledLocalizationTable(for: languageCode)

        state.lock.lock()
        state.localizedTables[languageCode] = loaded
        state.lock.unlock()
        return loaded
    }

    private static func loadCompiledLocalizationTable(for languageCode: String) -> [String: String] {
        guard let resourceURL = compiledLocalizationResourceURL(for: languageCode),
              let data = try? Data(contentsOf: resourceURL),
              let propertyList = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ),
              let table = propertyList as? [String: String]
        else {
            return [:]
        }

        return table
    }

    private static func localizationCandidates(for resolvedLanguageCode: String) -> [String] {
        switch resolvedLanguageCode {
        case "en":
            return ["en"]
        case "es":
            return ["es", "es-419"]
        case "pt-BR":
            return ["pt-BR", "pt"]
        case "fr":
            return ["fr", "fr-FR"]
        default:
            return [resolvedLanguageCode]
        }
    }

    private static func fallbackCatalogEntries() -> [String: [String: String]] {
        state.lock.lock()
        if let cached = state.fallbackCatalog {
            state.lock.unlock()
            return cached
        }
        state.lock.unlock()

        let loaded = loadFallbackCatalogEntries()

        state.lock.lock()
        state.fallbackCatalog = loaded
        state.lock.unlock()
        return loaded
    }

    private static func loadFallbackCatalogEntries() -> [String: [String: String]] {
        guard let url = Bundle.module.url(forResource: "Localizable", withExtension: "xcstrings"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(StringCatalog.self, from: data)
        else {
            return [:]
        }

        var resolved: [String: [String: String]] = [:]
        for (source, entry) in catalog.strings {
            let localizations = entry.localizations.compactMapValues { $0.stringUnit?.value }
            if !localizations.isEmpty {
                resolved[source] = localizations
            }
        }
        return resolved
    }
}

@MainActor
public final class AppLocalizationObserver: ObservableObject {
    public static let shared = AppLocalizationObserver()

    @Published public private(set) var revision = 0

    private init() {}

    public func invalidate() {
        revision += 1
    }
}

private struct StringCatalog: Decodable {
    let strings: [String: StringCatalogEntry]
}

private struct StringCatalogEntry: Decodable {
    let localizations: [String: StringCatalogLocalization]
}

private struct StringCatalogLocalization: Decodable {
    let stringUnit: StringCatalogStringUnit?
}

private struct StringCatalogStringUnit: Decodable {
    let value: String
}

// swiftlint:disable identifier_name
/// Canonical localization boundary for the app.
/// All keys use the Portuguese source string from the string catalog.
public func L10n(_ key: String) -> String {
    AppLocalization.localizedString(for: key)
}
// swiftlint:enable identifier_name
