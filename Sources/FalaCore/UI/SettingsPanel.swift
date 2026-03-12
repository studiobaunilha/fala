import Foundation

public enum SettingsPanel: String, CaseIterable, Identifiable, Sendable {
    case general = "Geral"
    case models = "Modelos"
    case advanced = "Avançado"
    case llm = "IA & LLM"
    case support = "Suporte"
    case about = "Sobre"

    public var id: String { self.rawValue }

    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .models: return "cpu"
        case .advanced: return "doc.text"
        case .llm: return "wand.and.stars"
        case .support: return "questionmark.circle"
        case .about: return "info.circle"
        }
    }

    public var localizedName: String {
        switch self {
        case .general: return L10n("Geral")
        case .models: return L10n("Motor de Transcrição")
        case .advanced: return L10n("Transcrição de Arquivos")
        case .llm: return L10n("IA & LLM")
        case .support: return L10n("Suporte")
        case .about: return L10n("Sobre")
        }
    }
}

public enum SettingsSelection: Hashable, Sendable {
    case panel(SettingsPanel)
    case template(DictationTemplate)
}
