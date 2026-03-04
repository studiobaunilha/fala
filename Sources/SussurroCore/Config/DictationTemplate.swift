import Foundation

public enum DictationTemplate: String, CaseIterable, Codable, Sendable {
    case raw = "Apenas Transcrever"
    case clean = "Limpar & Formatar"
    case translate = "Traduzir para Inglês"
    case bullets = "Criar Tópicos"
    case custom = "Personalizado"

    // Prompts Criativos
    case promptDev = "Prompt: Dev / Código"
    case promptImage = "Prompt: Imagem (Midjourney)"
    case promptVideo = "Prompt: Vídeo"

    public var icon: String {
        switch self {
        case .raw: return "text.alignleft"
        case .clean: return "wand.and.stars"
        case .translate: return "character.book.closed"
        case .bullets: return "list.bullet"
        case .custom: return "slider.horizontal.3"
        case .promptDev: return "terminal"
        case .promptImage: return "photo"
        case .promptVideo: return "video"
        }
    }

    public var defaultSystemPrompt: String? {
        switch self {
        case .raw, .translate, .custom:
            return nil
        case .clean:
            return "Formate o texto transcrito, corrigindo pontuação, gramática e capitalização, " +
                   "mantendo o idioma original. Não altere o sentido."
        case .bullets:
            return "Transforme o texto transcrito em uma lista de tópicos (bullet points) " +
                   "concisa e formatada em Markdown. Use hierarquia se necessário."
        case .promptDev:
            return "Atue como um Engenheiro de Software Senior. Transforme a solicitação transcrita " +
                   "em um prompt técnico detalhado, estruturado e otimizado para ser enviado a um " +
                   "LLM de código. IMPORTANTE: Você NÃO deve resolver o problema nem escrever o código " +
                   "solicitado. Sua única tarefa é gerar o texto da instrução (o prompt) para que " +
                   "outro sistema possa resolvê-lo."
        case .promptImage:
            return "Atue como um especialista em Prompt Engineering para Nano Banana/Midjourney/DALL-E. " +
                   "Transforme a descrição transcrita em um prompt detalhado em Inglês, focado " +
                   "em estilo visual, iluminação, composição e detalhes artísticos."
        case .promptVideo:
            return "Atue como um especialista em geração de vídeo (Veo/Sora/Runway). Transforme " +
                   "a descrição transcrita em um prompt estruturado descrevendo movimento, " +
                   "enquadramento de câmera, estilo e ação."
        }
    }

    public var requiresLLM: Bool {
        return self != .raw && self != .translate
    }

    public var modeDescription: String {
        switch self {
        case .raw:
            return "Transcrição direta sem processamento. O texto do Whisper é inserido como está."
        case .clean:
            return "Corrige pontuação, gramática e capitalização mantendo o conteúdo original."
        case .translate:
            return "Transcreve o áudio e traduz o resultado para inglês via Whisper."
        case .bullets:
            return "Organiza a transcrição em tópicos (bullet points) formatados em Markdown."
        case .custom:
            return "Modo personalizado com nome e prompt definidos por você."
        case .promptDev:
            return "Converte sua fala em um prompt técnico estruturado para LLMs de código."
        case .promptImage:
            return "Transforma descrições faladas em prompts detalhados para Nano Banana/Midjourney/DALL-E."
        case .promptVideo:
            return "Gera prompts estruturados para ferramentas de vídeo como Sora e Runway."
        }
    }

    /// Whether this is a creative/prompt-generation mode (vs. a basic transcription mode).
    public var isCreativeMode: Bool {
        switch self {
        case .promptDev, .promptImage, .promptVideo: return true
        default: return false
        }
    }
}
