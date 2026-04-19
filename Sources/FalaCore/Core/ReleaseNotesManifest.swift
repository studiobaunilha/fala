import Foundation

/// Describes a single released version with translated highlights.
public struct ReleaseNotesEntry: Codable, Equatable, Sendable, Identifiable {
    public let version: String
    public let date: String
    /// Keys are language codes (e.g. "pt-BR", "en", "es", "fr"). Values are
    /// bullet lists, already ordered.
    public let highlights: [String: [String]]

    public var id: String { version }

    /// Localized highlights for the current app language, with fallback to
    /// English, then Portuguese (the source language).
    public func localizedHighlights(
        languageCode: String = AppLocalization.resolvedLanguageCode()
    ) -> [String] {
        if let list = highlights[languageCode], !list.isEmpty {
            return list
        }
        if let list = highlights["en"], !list.isEmpty {
            return list
        }
        return highlights["pt-BR"] ?? []
    }
}

public struct ReleaseNotesManifest: Codable, Sendable {
    public let releases: [ReleaseNotesEntry]
}

public enum ReleaseNotesManifestLoader {
    public static func load() -> [ReleaseNotesEntry] {
        load(bundle: .module)
    }

    /// Returns the entry whose version exactly matches `version`, or nil.
    public static func entry(for version: String) -> ReleaseNotesEntry? {
        load().first { $0.version == version }
    }

    static func load(bundle: Bundle) -> [ReleaseNotesEntry] {
        guard let url = bundle.url(forResource: "ReleaseNotes", withExtension: "json") else {
            NSLog("[Fala] ReleaseNotes.json missing from bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let manifest = try JSONDecoder().decode(ReleaseNotesManifest.self, from: data)
            return manifest.releases
        } catch {
            NSLog("[Fala] Failed to decode ReleaseNotes.json: %@", error.localizedDescription)
            return []
        }
    }
}
