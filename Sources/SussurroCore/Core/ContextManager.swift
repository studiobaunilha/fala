import Foundation

@MainActor
public final class ContextManager {
    public static let shared = ContextManager()
    
    private var summary: String = ""
    
    private init() {}
    
    public func clear() {
        summary = ""
    }
    
    public func buildPrompt(basePrompt: String) -> String {
        guard !summary.isEmpty else { return basePrompt }
        
        return """
        \(basePrompt)
        
        ---
        ATENÇÃO - CONTEXTO ANTERIOR:
        Abaixo está um resumo do contexto recente da nossa conversa/trabalho. 
        Use as informações deste resumo APENAS para resolver ambiguidades 
        (ex: pronomes, siglas, jargões, nomes) na nova entrada.
        Não inclua este resumo na sua resposta final.
        Você deve retornar APENAS a nova entrada processada.
        
        [Resumo do Contexto]
        \(summary)
        """
    }
    
    public func updateSummary(newText: String, config: AppConfig) async {
        guard config.enableContextBuffer else { return }
        
        let prompt = """
        Atue como um assistente de memória. Sua tarefa é atualizar o resumo do 
        contexto de uma sessão de ditado com base na nova entrada do usuário.
        Mantenha o resumo conciso (máximo 2 parágrafos), focando em capturar: 
        nomes próprios, tópicos principais, jargões técnicos e contexto geral.
        Não responda a perguntas, apenas crie/atualize o resumo.
        Se o resumo atual for "Nenhum", apenas resuma a nova entrada.
        
        Resumo Atual:
        \(summary.isEmpty ? "Nenhum" : summary)
        """
        
        do {
            let updatedSummary: String
            if config.llmProvider == "gemini", !config.geminiKey.isEmpty {
                updatedSummary = try await TranscriptionJob.processWithGemini(
                    text: newText,
                    prompt: prompt,
                    apiKey: config.geminiKey,
                    model: config.geminiModel
                )
            } else if config.llmProvider == "openai", !config.openAIKey.isEmpty {
                updatedSummary = try await TranscriptionJob.processWithOpenAI(
                    text: newText,
                    prompt: prompt,
                    apiKey: config.openAIKey,
                    model: config.openAIModel
                )
            } else {
                return
            }
            
            self.summary = updatedSummary
            print("[Sussurro] Contexto atualizado.")
        } catch {
            print("[Sussurro] Falha ao atualizar contexto: \(error.localizedDescription)")
        }
    }
}
