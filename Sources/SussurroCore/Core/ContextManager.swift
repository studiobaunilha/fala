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
    public func buildPrompt(basePrompt: String) -> String {
        guard !contextNotes.isEmpty else { return basePrompt }
        
        return """
        \(basePrompt)
        
        ---
        [INFORMACÃO DE CONTEXTO & MEMÓRIA]
        Use as notas abaixo para refinar a transcrição (estilo, vocabulário, contexto do projeto).
        NÃO inclua estas notas na saída, apenas use-as para guiar a transformação.
        
        Notas Atuais:
        \(contextNotes)
        """
    }
    
    /// Atualiza as notas de contexto com base na nova entrada.
    public func updateContext(newInput: String, config: AppConfig) async {
        guard config.enableContextBuffer else { return }
        
        let systemPrompt = """
        Atue como um Assistente de Memória (AI Memory Manager).
        Sua tarefa é manter um conjunto de notas concisas sobre a sessão atual.
        Atualize as notas para refletir o estado atual, intenção, tom e entidades chave (nomes, projetos, tecnologias).
        Remova informações obsoletas. Mantenha o formato de tópicos curtos.
        Não responda ao usuário. Apenas retorne as notas atualizadas.
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
