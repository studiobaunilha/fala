import Foundation

enum SettingsPanel: String, CaseIterable, Identifiable {
    case general = "Geral"
    case models = "Modelos"
    case advanced = "Avançado"
    case llm = "IA & LLM"
    case license = "Licença"
    case about = "Sobre"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .models: return "cpu"
        case .advanced: return "gearshape.2"
        case .llm: return "wand.and.stars"
        case .license: return "key.fill"
        case .about: return "info.circle"
        }
    }
    
    var localizedName: String {
        switch self {
        case .general: return L10n("Geral")
        case .models: return L10n("Modelos")
        case .advanced: return L10n("Avançado")
        case .llm: return L10n("IA & LLM")
        case .license: return L10n("Licença")
        case .about: return L10n("Sobre")
        }
    }
}

enum SettingsSelection: Hashable {
    case panel(SettingsPanel)
    case template(DictationTemplate)
}
