import Combine
import Foundation

public enum AppLocalization {
    public static let supportedAppLanguageCodes = ["pt-BR", "en", "es"]
    public static let languageChangedNotification = Notification.Name("dev.fala.app-language-changed")

    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var overrideLanguageCode = "auto"
        var localizedCatalog: [String: [String: String]]?
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

        let catalog = catalogEntries()
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
        return nil
    }

    private static func catalogEntries() -> [String: [String: String]] {
        state.lock.lock()
        if let cached = state.localizedCatalog {
            state.lock.unlock()
            return cached
        }
        state.lock.unlock()

        let loaded = loadCatalogEntries()

        state.lock.lock()
        state.localizedCatalog = loaded
        state.lock.unlock()
        return loaded
    }

    private static func loadCatalogEntries() -> [String: [String: String]] {
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
