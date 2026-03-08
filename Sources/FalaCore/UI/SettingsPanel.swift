import Foundation

public enum SettingsPanel: String, CaseIterable, Identifiable, Sendable {
    case general = "Geral"
    case models = "Modelos"
    case advanced = "Avançado"
    case llm = "IA & LLM"
    case license = "Licença"
    case updates = "Atualizações"
    case about = "Sobre"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .models: return "cpu"
        case .advanced: return "gearshape.2"
        case .llm: return "wand.and.stars"
        case .license: return "key.fill"
        case .updates: return "arrow.triangle.2.circlepath"
        case .about: return "info.circle"
        }
    }
    
    public var localizedName: String {
        switch self {
        case .general: return L10n("Geral")
        case .models: return L10n("Motor de Transcrição")
        case .advanced: return L10n("Avançado")
        case .llm: return L10n("IA & LLM")
        case .license: return L10n("Licença")
        case .updates: return L10n("Atualizações")
        case .about: return L10n("Sobre")
        }
    }
}

public enum SettingsSelection: Hashable, Sendable {
    case panel(SettingsPanel)
    case template(DictationTemplate)
}
