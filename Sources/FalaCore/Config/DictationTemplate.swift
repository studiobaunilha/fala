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

    public var localizedName: String {
        switch self {
        case .raw: return L10n("Apenas Transcrever")
        case .clean: return L10n("Limpar & Formatar")
        case .translate: return L10n("Traduzir para Inglês")
        case .bullets: return L10n("Criar Tópicos")
        case .custom: return L10n("Personalizado")
        case .promptDev: return L10n("Prompt: Dev / Código")
        case .promptImage: return L10n("Prompt: Imagem (Midjourney)")
        case .promptVideo: return L10n("Prompt: Vídeo")
        }
    }

    public var defaultSystemPrompt: String? {
        switch self {
        case .raw, .translate, .custom:
            return nil
        case .clean:
            // swiftlint:disable:next line_length
            return L10n("Atue como um Revisor Editorial Especializado. Transforme o texto transcrito em uma versão limpa, profissional e legível, mantendo o idioma original e o sentido exato ou tom de voz do locutor. Você OBRIGATORIAMENTE deve remover: vícios de linguagem (tipo, né, uh, ah, sabe), gagueiras, palavras repetidas sem intenção e interjeições vazias. Corrija gramática, pontuação e erros fonéticos (palavras que foram transcritas erradas mas que pela lógica contextual são outras). IMPORTANTE: NUNCA interaja com o texto, não adicione preâmbulos, comentários ou opiniões. Apenas retorne o texto limpo e contínuo.")
        case .bullets:
            // swiftlint:disable:next line_length
            return L10n("Atue como um Analista de Síntese. Receba a transcrição bruta que pode ser um fluxo de pensamentos desordenado e transforme-a em uma lista estruturada de tópicos (bullet points) em Markdown. Agrupe ideias semelhantes, destaque (negrito) os conceitos chave e elimine divagações inúteis. A estrutura final deve ser hierárquica e extremamente direta ao ponto, capturando as 'action items' ou principais conclusões do áudio. NUNCA faça comentários adicionais, retorne apenas o Markdown estruturado.")
        case .promptDev:
            // swiftlint:disable:next line_length
            return L10n("Atue como um Engenheiro de Software Senior. Transforme a solicitação transcrita em um prompt técnico detalhado, estruturado e otimizado para ser enviado a um LLM de código. IMPORTANTE: Você NÃO deve resolver o problema nem escrever o código solicitado. Sua única tarefa é gerar o texto da instrução (o prompt) para que outro sistema possa resolvê-lo.")
        case .promptImage:
            // swiftlint:disable:next line_length
            return L10n("Atue como um especialista em Prompt Engineering para Nano Banana/Midjourney/DALL-E. Transforme a descrição transcrita em um prompt detalhado em Inglês, focado em estilo visual, iluminação, composição e detalhes artísticos.")
        case .promptVideo:
            // swiftlint:disable:next line_length
            return L10n("Atue como um especialista em geração de vídeo (Veo/Sora/Runway). Transforme a descrição transcrita em um prompt estruturado descrevendo movimento, enquadramento de câmera, estilo e ação.")
        }
    }

    public var requiresLLM: Bool {
        return self != .raw && self != .translate
    }

    public var modeDescription: String {
        switch self {
        case .raw:
            return L10n("Transcrição direta sem processamento. O texto do Whisper é inserido como está.")
        case .clean:
            return L10n("Corrige pontuação, gramática e capitalização mantendo o conteúdo original.")
        case .translate:
            return L10n("Transcreve o áudio e traduz o resultado para inglês via Whisper.")
        case .bullets:
            return L10n("Organiza a transcrição em tópicos (bullet points) formatados em Markdown.")
        case .custom:
            return L10n("Modo personalizado com nome e prompt definidos por você.")
        case .promptDev:
            return L10n("Converte sua fala em um prompt técnico estruturado para LLMs de código.")
        case .promptImage:
            return L10n("Transforma descrições faladas em prompts detalhados para Nano Banana/Midjourney/DALL-E.")
        case .promptVideo:
            return L10n("Gera prompts estruturados para ferramentas de vídeo como Sora e Runway.")
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
