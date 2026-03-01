import Foundation

public struct AppConfig: Codable {
    public var dictationModel: String = "large-v3-turbo"
    public var batchModel: String     = "large-v3-turbo"
    public var outputFormat: String   = "txt"     // "txt" or "md"
    public var language: String       = "auto"    // "auto" or BCP-47 code, e.g. "pt", "en"
    
    // Advanced Transcription Settings
    public var dictationTemperature: Float = 0.0
    public var batchTemperature: Float = 0.0
    public var customDictionary: [String] = [] // Used as initial_prompt
    public var enableDiarization: Bool = false // Toggle for speaker recognition
    
    // Default Export Location
    public var defaultExportPath: String = FileManager.default.urls(
        for: .downloadsDirectory, in: .userDomainMask
    ).first?.path ?? ""
    
    // LLM Post-Processing
    public var enableLLMPostProcessing: Bool = false
    public var llmProvider: String = "gemini" // "gemini" or "openai"
    public var llmPrompt: String =
        "Formate e corrija a transcrição abaixo, mantendo o idioma original e corrigindo pontuação."
    public var openAIKey: String = ""
    public var geminiKey: String = ""

    public init() {}

    // Custom decoder so that adding new fields never breaks existing config files:
    // missing keys fall back to the property default rather than throwing.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dictationModel = (try? container.decode(String.self, forKey: .dictationModel)) ?? "large-v3-turbo"
        batchModel     = (try? container.decode(String.self, forKey: .batchModel))     ?? "large-v3-turbo"
        outputFormat   = (try? container.decode(String.self, forKey: .outputFormat))   ?? "txt"
        language       = (try? container.decode(String.self, forKey: .language))       ?? "auto"
        
        dictationTemperature = (try? container.decode(Float.self, forKey: .dictationTemperature)) ?? 0.0
        batchTemperature     = (try? container.decode(Float.self, forKey: .batchTemperature)) ?? 0.0
        
        // Handle legacy string dictionary migration to array
        if let stringDict = try? container.decode(String.self, forKey: .customDictionary) {
            let split = stringDict.split(separator: ",")
            customDictionary = split.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        } else {
            customDictionary = (try? container.decode([String].self, forKey: .customDictionary)) ?? []
        }
        
        enableDiarization    = (try? container.decode(Bool.self, forKey: .enableDiarization)) ?? false
        
        defaultExportPath    = (try? container.decode(String.self, forKey: .defaultExportPath)) ??
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ""
        
        enableLLMPostProcessing = (try? container.decode(Bool.self, forKey: .enableLLMPostProcessing)) ?? false
        llmProvider = (try? container.decode(String.self, forKey: .llmProvider)) ?? "gemini"
        let defaultPrompt = "Formate e corrija a transcrição abaixo, mantendo o idioma original e corrigindo pontuação."
        llmPrompt = (try? container.decode(String.self, forKey: .llmPrompt)) ?? defaultPrompt
        openAIKey = (try? container.decode(String.self, forKey: .openAIKey)) ?? ""
        geminiKey = (try? container.decode(String.self, forKey: .geminiKey)) ?? ""
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
