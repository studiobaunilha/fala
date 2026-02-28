import Foundation

public struct AppConfig: Codable {
    public var dictationModel: String = "large-v3-turbo"
    public var batchModel: String     = "large-v3-turbo"
    public var outputFormat: String   = "txt"     // "txt" or "md"

    public init() {}

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
