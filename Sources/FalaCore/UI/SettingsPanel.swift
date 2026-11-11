import Foundation

public enum SettingsPanel: String, CaseIterable, Identifiable, Sendable {
    case general = "Geral"
    case contexts = "Contextos"
    case models = "Modelos"
    case llm = "IA & LLM"
    case support = "Suporte"
    case about = "Sobre"

    public var id: String { self.rawValue }

    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .contexts: return "text.book.closed"
        case .models: return "cpu"
        case .llm: return "wand.and.stars"
        case .support: return "questionmark.circle"
        case .about: return "info.circle"
        }
    }

    public var localizedName: String {
        switch self {
        case .general: return L10n("Geral")
        case .contexts: return L10n("Contextos")
        case .models: return L10n("Motor de Transcrição")
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
