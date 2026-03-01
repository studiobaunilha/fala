import Foundation

public struct AppConfig: Codable {
    public var dictationModel: String = "large-v3-turbo"
    public var batchModel: String     = "large-v3-turbo"
    public var outputFormat: String   = "txt"     // "txt" or "md"
    public var language: String       = "auto"    // "auto" or BCP-47 code, e.g. "pt", "en"

    public init() {}

    // Custom decoder so that adding new fields never breaks existing config files:
    // missing keys fall back to the property default rather than throwing.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dictationModel = (try? container.decode(String.self, forKey: .dictationModel)) ?? "large-v3-turbo"
        batchModel     = (try? container.decode(String.self, forKey: .batchModel))     ?? "large-v3-turbo"
        outputFormat   = (try? container.decode(String.self, forKey: .outputFormat))   ?? "txt"
        language       = (try? container.decode(String.self, forKey: .language))       ?? "auto"
    }

    // MARK: – Persistence

    private static var configURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/sussurro")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    public static func load() -> AppConfig {
        guard
            let data = try? Data(contentsOf: configURL),
            let config = try? JSONDecoder().decode(AppConfig.self, from: data)
        else { return AppConfig() }
        return config
    }

    public func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: AppConfig.configURL)
    }
}
