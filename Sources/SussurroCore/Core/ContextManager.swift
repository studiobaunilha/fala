import Foundation
import Combine

@MainActor
public final class ContextManager: ObservableObject {
    public static let shared = ContextManager()
    
    @Published public var contextNotes: String = ""
    
    // Legacy alias for compatibility if needed, but we should update call sites
    public var summary: String {
        get { contextNotes }
        set { contextNotes = newValue }
    }
    
    private init() {}
    
    public func clear() {
        contextNotes = ""
    }
    
    /// Constrói o prompt final combinando o prompt do template com as notas de contexto.
    /// - Memória vazia: prompt base + instruções de qualidade (primeira interação da sessão)
    /// - Memória preenchida: prompt base + notas da sessão para refinamento contextual
    public func buildPrompt(basePrompt: String) -> String {
        if contextNotes.isEmpty {
            return """
            \(basePrompt)

            ---
            [INSTRUÇÕES DE QUALIDADE]
            Esta é a primeira transcrição da sessão. Aplique o máximo cuidado com:
            - Pontuação, gramática e capitalização
            - Nomes próprios e termos técnicos (preserve a grafia correta)
            - Tom e registro adequado ao contexto
            - Coerência e clareza geral
            Retorne APENAS o texto processado, sem explicações ou comentários.
            """
        } else {
            return """
            \(basePrompt)

            ---
            [CONTEXTO DA SESSÃO — NOTAS DA IA]
            As notas abaixo foram coletadas de interações anteriores nesta sessão.
            Use-as para refinar a transcrição: vocabulário preferido, tom, termos recorrentes,
            contexto do projeto/assunto em andamento.
            NÃO inclua estas notas na saída. Apenas use-as para produzir uma transcrição
            mais polida e contextualizada.

            \(contextNotes)
            """
        }
    }
    
    /// Atualiza as notas de contexto com base na nova entrada.
    public func updateContext(newInput: String, config: AppConfig) async {
        guard config.enableContextBuffer else { return }
        
        let systemPrompt = """
        Atue como um Assistente de Memória para Transcrição (AI Memory Manager).
        Sua tarefa é manter notas concisas que MELHOREM futuras transcrições.
        Organize as notas nas seguintes categorias (use apenas as relevantes):
        - TOM: (ex: formal, casual, técnico, animado)
        - ASSUNTO: (tópico atual sendo discutido)
        - ENTIDADES: (nomes, projetos, tecnologias, termos específicos mencionados)
        - VOCABULÁRIO: (palavras/jargões preferidos, correções recorrentes)
        - INTENÇÃO: (o que o usuário está fazendo — email, código, notas, apresentação)
        Mantenha tópicos curtos e objetivos. Remova informações obsoletas ou redundantes.
        Não responda ao usuário. Retorne APENAS as notas atualizadas.
        """
        
        let userMessage = """
        [Notas Atuais]:
        \(contextNotes.isEmpty ? "Nenhuma" : contextNotes)
        
        [Nova Entrada do Usuário]:
        "\(newInput)"
        """
        
        do {
            let updatedNotes: String
            // Use the global LLM provider for context updates
            if config.llmProvider == "gemini", !config.geminiKey.isEmpty {
                updatedNotes = try await TranscriptionJob.processWithGemini(
                    text: userMessage,
                    prompt: systemPrompt,
                    apiKey: config.geminiKey,
                    model: config.geminiModel
                )
            } else if config.llmProvider == "openai", !config.openAIKey.isEmpty {
                updatedNotes = try await TranscriptionJob.processWithOpenAI(
                    text: userMessage,
                    prompt: systemPrompt,
                    apiKey: config.openAIKey,
                    model: config.openAIModel
                )
            } else if config.llmProvider == "apple" {
                updatedNotes = try await TranscriptionJob.processWithAppleNative(
                    text: userMessage,
                    prompt: systemPrompt
                )
            } else {
                return
            }
            
            self.contextNotes = updatedNotes
            print("[Sussurro] Memória de contexto atualizada.")
        } catch {
            print("[Sussurro] Falha ao atualizar memória: \(error.localizedDescription)")
        }
    }
    
    // Legacy support wrapper
    public func updateSummary(newText: String, config: AppConfig) async {
        await updateContext(newInput: newText, config: config)
    }
}
