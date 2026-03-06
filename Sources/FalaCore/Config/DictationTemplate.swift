import Foundation

public enum DictationTemplate: String, CaseIterable, Codable, Sendable {
    case raw = "Apenas Transcrever"
    case translate = "Traduzir para Inglês"
    case custom = "Personalizado"

    // Assistente
    case askAI = "Perguntar à IA"

    public var icon: String {
        switch self {
        case .raw: return "text.alignleft"
        case .translate: return "character.book.closed"
        case .custom: return "slider.horizontal.3"
        case .askAI: return "bubble.left.and.text.bubble.right"
        }
    }

    public var localizedName: String {
        switch self {
        case .raw: return L10n("Apenas Transcrever")
        case .translate: return L10n("Traduzir para Inglês")
        case .custom: return L10n("Personalizado")
        case .askAI: return L10n("Perguntar à IA")
        }
    }

    public var defaultSystemPrompt: String? {
        switch self {
        case .raw, .translate, .custom:
            return nil
        case .askAI:
            // swiftlint:disable:next line_length
            return L10n("Você é um assistente inteligente. A mensagem do usuário é uma pergunta ou solicitação transcrita por voz. Responda de forma clara, útil e concisa.")
        }
    }

    public var requiresLLM: Bool {
        return self != .raw && self != .translate
    }

    /// Whether the user input should be treated as a question/command for the AI,
    /// rather than text to be processed/formatted.
    public var isConversational: Bool {
        return self == .askAI
    }

    public var modeDescription: String {
        switch self {
        case .raw:
            return L10n("Transcrição direta sem processamento. O texto do Whisper é inserido como está.")
        case .translate:
            return L10n("Transcreve o áudio e traduz o resultado para inglês via Whisper.")
        case .custom:
            return L10n("Modo personalizado com nome e prompt definidos por você.")
        case .askAI:
            // swiftlint:disable:next line_length
            return L10n("Fale sua pergunta e a IA responde. Diferente dos outros modos, aqui a IA trata sua fala como uma pergunta e retorna uma resposta.")
        }
    }
}
