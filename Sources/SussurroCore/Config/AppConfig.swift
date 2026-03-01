import Foundation

public struct AppConfig: Codable, Sendable {
    public var dictationModel: String = "large-v3-turbo"
    public var batchModel: String     = "large-v3-turbo"
    public var outputFormat: String   = "txt"
    public var language: String       = "auto"
    
    public var dictationTemperature: Float = 0.0
    public var batchTemperature: Float = 0.0
    public var customDictionary: [String] = []
    public var enableDiarization: Bool = false
    
    public var defaultExportPath: String = FileManager.default.urls(
        for: .downloadsDirectory, in: .userDomainMask
    ).first?.path ?? ""
    
    public var enableContextBuffer: Bool = false
    public var enableLLMPostProcessing: Bool = false
    public var selectedDictationTemplate: DictationTemplate = .clean
    public var llmProvider: String = "gemini"
    public var llmPrompt: String =
        "Formate e corrija a transcrição abaixo, mantendo o idioma original e corrigindo pontuação."
    public var openAIKey: String = ""
    public var geminiKey: String = ""
    public var geminiModel: String = "gemini-2.5-flash"
    public var openAIModel: String = "gpt-4o-mini"
    
    public var replacements: [String: String] = [:]
    public var modeConfigs: [String: ModeConfig] = [:]

    private static let storageKey = "dev.sussurro.config"

    public init() {}

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
        
        replacements = (try? container.decode([String: String].self, forKey: .replacements)) ?? [:]
        modeConfigs = (try? container.decode([String: ModeConfig].self, forKey: .modeConfigs)) ?? [:]
        
        enableDiarization = (try? container.decode(Bool.self, forKey: .enableDiarization)) ?? false
        
        defaultExportPath = (try? container.decode(String.self, forKey: .defaultExportPath)) ??
            FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? ""
        
        enableContextBuffer = (try? container.decode(Bool.self, forKey: .enableContextBuffer)) ?? false
        enableLLMPostProcessing = (try? container.decode(Bool.self, forKey: .enableLLMPostProcessing)) ?? false
        
        let decodedTemplate = try? container.decode(DictationTemplate.self, forKey: .selectedDictationTemplate)
        selectedDictationTemplate = decodedTemplate ?? .clean
        
        llmProvider = (try? container.decode(String.self, forKey: .llmProvider)) ?? "gemini"
        
        let defaultPrompt = "Formate e corrija a transcrição abaixo, mantendo o idioma original e corrigindo pontuação."
        llmPrompt = (try? container.decode(String.self, forKey: .llmPrompt)) ?? defaultPrompt
        openAIKey = (try? container.decode(String.self, forKey: .openAIKey)) ?? ""
        geminiKey = (try? container.decode(String.self, forKey: .geminiKey)) ?? ""
        geminiModel = (try? container.decode(String.self, forKey: .geminiModel)) ?? "gemini-2.5-flash"
        openAIModel = (try? container.decode(String.self, forKey: .openAIModel)) ?? "gpt-4o-mini"
    }
    
    // MARK: – Helper Methods for Mode Config
    
    public struct EffectiveConfig {
        public let provider: String
        public let model: String
        public let prompt: String
    }
    
    public func getEffectiveConfig(for template: DictationTemplate) -> EffectiveConfig {
        let modeConfig = modeConfigs[template.rawValue]
        
        let provider = modeConfig?.provider ?? llmProvider
        
        // 1. Custom prompt from mode config
        // 2. Default prompt from template definition
        // 3. Fallback to empty string (prevents forcing LLM on raw/translate)
        let prompt = modeConfig?.prompt ?? template.defaultSystemPrompt ?? ""
        
        let model: String
        if let modeModel = modeConfig?.model, !modeModel.isEmpty {
            model = modeModel
        } else {
            // Fallback to global model based on provider
            model = (provider == "gemini") ? geminiModel : (provider == "openai" ? openAIModel : "")
        }
        
        return EffectiveConfig(provider: provider, model: model, prompt: prompt)
    }

    // MARK: – Persistence (UserDefaults)

    public static func load() -> AppConfig {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
            UserDefaults.standard.synchronize()
        }
    }
}

public struct ModeConfig: Codable, Sendable, Equatable {
    public var provider: String? // "openai", "gemini", "apple", or nil (use global)
    public var model: String?    // Specific model or nil (use global)
    public var prompt: String?   // Custom system prompt or nil (use default)
    
    public init(provider: String? = nil, model: String? = nil, prompt: String? = nil) {
        self.provider = provider
        self.model = model
        self.prompt = prompt
    }
}
