# Reestruturar Prompts por Modelo + Memória de Conversação askAI

## Context

O sistema de prompts atual usa um `globalSystemPrompt` que é concatenado ao prompt do template e enviado igualmente para todos os providers/modelos. Isso causa:
- Prompts longos em português consumindo contexto de modelos locais pequenos (Qwen3-4B: ~4096 tokens)
- Saída com `<think>...</think>` do Qwen3 vazando no texto inserido
- Mesmo prompt verboso para GPT-4o (128k tokens) e modelos locais de 4B params
- UX confusa: usuário gerencia globalSystemPrompt + prompt do template separadamente

Adicionalmente, o modo askAI não mantém nenhum histórico — cada chamada é isolada, perdendo contexto de perguntas anteriores.

---

## Phase 1 — Quick Wins (sem breaking changes)

### 1a. Strip `<think>` tags da saída

**Arquivo:** `TranscriptionJob+Processing.swift` — função `stripLLMPreamble()`

Adicionar strip de `<think>...</think>` antes do strip de preâmbulo existente:
```swift
// Strip thinking tags (Qwen3, DeepSeek R1, etc.)
text = text.replacingOccurrences(
    of: "<think>[\\s\\S]*?</think>\\s*",
    with: "",
    options: .regularExpression
)
// Also handle unclosed <think> tags (model hit token limit mid-thought)
text = text.replacingOccurrences(
    of: "<think>[\\s\\S]*$",
    with: "",
    options: .regularExpression
)
```

### 1b. Adicionar `/no_think` para Qwen3 no prompt MLX

Quando o modelo for Qwen3 e o template NÃO for conversational, prefixar o prompt com `/no_think` para suprimir geração de pensamento (economiza tokens e latência).

**Arquivo:** `DictationMode.swift` — `buildLLMPrompt()` ou no dispatch MLX

---

## Phase 2 — Reestruturação de Prompts

### Objetivo
Substituir `globalSystemPrompt + prompt do template` por **um prompt completo e autocontido por provider**, com defaults inteligentes por categoria de modelo.

### 2a. Novo modelo de dados

**Arquivo:** `AppConfig.swift`

```swift
// Substituir globalSystemPrompt por prompts per-provider no ModeConfig
struct ModeConfig: Codable, Sendable {
    var provider: String?
    var model: String?
    var prompt: String?         // Prompt principal do template (mantém)
    var providerPrompts: [String: String]?  // Override per-provider (NOVO)
}
```

Resolução do prompt efetivo:
1. `modeConfigs[template]?.providerPrompts?[provider]` — override específico
2. `modeConfigs[template]?.prompt` — prompt geral do template
3. `PromptDefaults.default(for: provider, template: template)` — default hardcoded
4. `template.defaultSystemPrompt` — fallback final

### 2b. Defaults hardcoded por provider

**Novo arquivo:** `PromptDefaults.swift`

```swift
enum PromptDefaults {
    static func `default`(for provider: String, template: DictationTemplate) -> String
}
```

Defaults otimizados:
- **Gemini/OpenAI**: Prompt completo em português com hardening (equivalente ao globalSystemPrompt + template prompt atuais)
- **Apple Intelligence**: Prompt curto em inglês (~50 palavras), otimizado para 3B params
- **MLX (geral)**: Prompt conciso em inglês, sem redundâncias, otimizado para contexto curto
- **MLX (Qwen3)**: Inclui `/no_think` + prompt em inglês

### 2c. Eliminar globalSystemPrompt

**Arquivos afetados:**
- `AppConfig.swift` — marcar `globalSystemPrompt` como deprecated, manter para migração
- `DictationMode.swift` — `buildLLMPrompt()` deixa de concatenar com `---` separator
- `TranscriptionJob+Processing.swift` — `wrapPromptForCleanOutput()` simplificada
- `SettingsView+LLM.swift` — remover editor do global prompt
- `SettingsView+Modes.swift` — adicionar seletor de prompt por provider no ModeDetailView

### 2d. Migração

Na primeira execução após a atualização:
- Se `globalSystemPrompt` != default, copiar para os prompts per-provider dos templates que usam LLM
- Se `globalSystemPrompt` == default, usar novos defaults sem copiar
- Limpar `globalSystemPrompt` após migração

### 2e. UI de Settings

No `ModeDetailView` (SettingsView+Modes.swift):
- Manter o seletor de provider/modelo existente
- O editor de prompt mostra o prompt **do provider selecionado** (não mais um prompt "geral")
- Botão "Restaurar padrão" restaura o default daquele provider específico
- Cada provider tem seu tab ou segmented control com o prompt

---

## Phase 3 — Memória de Conversação para askAI

### Estado atual
- Cada chamada askAI cria um `ChatSession` novo (MLX) ou envia apenas 1 mensagem user (APIs)
- Zero contexto entre chamadas
- `LanguageModelSession` (Apple) e `ChatSession` (MLX) suportam history nativamente

### 3a. ConversationMemory

**Novo arquivo:** `ConversationMemory.swift`

```swift
@MainActor
final class ConversationMemory {
    struct Turn: Sendable {
        let role: String      // "user" | "assistant"
        let content: String
        let timestamp: Date
    }

    private(set) var turns: [Turn] = []
    let maxTurns: Int         // Janela de contexto (default: 10 turnos = 5 Q&A)

    func append(userText: String, assistantResponse: String)
    func clear()
    func messagesForAPI() -> [[String: String]]  // Para OpenAI/Gemini format
    var contextSummary: String  // Para providers que não suportam multi-turn
}
```

### 3b. Integração por provider

**OpenAI/Gemini**: Enviar array de messages com histórico completo
```swift
"messages": [
    {"role": "system", "content": prompt},
    {"role": "user", "content": "pergunta 1"},
    {"role": "assistant", "content": "resposta 1"},
    {"role": "user", "content": "pergunta atual"}
]
```

**MLX**: Reusar `ChatSession` entre chamadas (em vez de criar nova a cada vez)
- `MLXModelCache` mantém `ChatSession` por `(repoID, template)`
- Reset quando o usuário troca de modelo ou template

**Apple Intelligence**: `LanguageModelSession` já suporta multi-turn via `respond(to:)` consecutivos
- Manter a sessão entre chamadas askAI

### 3c. Lifecycle da memória

- **Reset automático**: Após 5 minutos de inatividade (configurável)
- **Reset manual**: Atalho de teclado ou botão no feedback view
- **Indicador visual**: Badge no feedback view mostrando "3 turnos" ou similar
- **Persistência**: Apenas em memória (não persiste entre sessões do app)

### 3d. DictationMode changes

- `DictationMode` recebe referência ao `ConversationMemory`
- No flow askAI: antes de chamar LLM, inclui histórico da memória
- Após resposta: salva par (pergunta, resposta) na memória
- Templates não-conversacionais ignoram a memória

---

## Phase 4 — Contexto de Seleção para askAI

### Objetivo
Permitir que o usuário selecione texto em qualquer app, ative o askAI, e a IA responda com base no texto selecionado + a pergunta falada. Futuro: screenshot/OCR como contexto visual.

### 4a. Captura de seleção ativa

**Novo arquivo:** `SelectionCapture.swift`

Ao ativar o askAI (keyDown), antes de iniciar a gravação:
1. Simular Cmd+C via CGEvent para copiar a seleção atual
2. Ler o clipboard, guardar como `selectedContext`
3. Restaurar o clipboard original
4. Se houver seleção, incluir como contexto no prompt

```swift
struct SelectionCapture {
    static func captureCurrentSelection() -> String?
    // Salva clipboard -> Cmd+C -> lê -> restaura clipboard original
}
```

### 4b. Integração com prompt

Quando houver texto selecionado, envolver a mensagem do usuário:
```
Contexto (texto selecionado pelo usuário):
---
[texto selecionado]
---

Pergunta do usuário:
[transcrição de voz]
```

### 4c. Integração com ConversationMemory

- A seleção é tratada como contexto do turno atual, não como parte do histórico
- Próximas perguntas do mesmo "thread" podem referenciar o contexto original
- O contexto selecionado aparece no primeiro turno da memória

### 4d. Futuro: Screenshot/OCR como contexto

- Atalho alternativo (ex: Cmd+Option+Space) para capturar screenshot da janela ativa
- OCR via Vision framework para extrair texto
- Ou enviar imagem diretamente para providers que suportam (Gemini, OpenAI)
- Escopo: apenas planejamento, implementação em versão futura

---

## Arquivos críticos a modificar

| Arquivo | Phase |
|---------|-------|
| `TranscriptionJob+Processing.swift` | 1a, 2c |
| `DictationMode.swift` | 1b, 2c, 3d |
| `AppConfig.swift` | 2a, 2c, 2d |
| `PromptDefaults.swift` (novo) | 2b |
| `SettingsView+LLM.swift` | 2c |
| `SettingsView+Modes.swift` | 2e |
| `ConversationMemory.swift` (novo) | 3a |
| `MLXModelManager.swift` | 3b |
| `TranscriptionJob+LLMProcessing.swift` | 2c, 3b |
| `AppDelegate.swift` | 3d |
| `SelectionCapture.swift` (novo) | 4a |

---

## Verificação

### Phase 1
- [x] Transcrever com Qwen3 em modo custom: texto NÃO contém `<think>` tags
- [x] Transcrever com Qwen3: resposta mais rápida (sem geração de pensamento)
- [x] Modelos sem thinking tags continuam funcionando normalmente

### Phase 2
- [x] Novo app carrega defaults por provider sem globalSystemPrompt
- [x] App com config antiga migra globalSystemPrompt customizado corretamente
- [x] Trocar provider no Settings atualiza o prompt exibido
- [x] "Restaurar padrão" restaura default do provider, não um default global
- [x] Gemini/OpenAI recebem prompt otimizado em português
- [x] MLX recebe prompt conciso adequado ao modelo
- [x] Apple Intelligence recebe prompt curto

### Phase 3
- [ ] askAI mantém contexto entre chamadas consecutivas
- [ ] Perguntar "e sobre X?" funciona com referência à resposta anterior
- [ ] Memória reseta após 5 min de inatividade
- [ ] Trocar template/modelo limpa a memória
- [ ] Feedback view mostra indicador de turnos ativos
- [ ] Testes unitários cobrem ConversationMemory

### Phase 4
- [ ] Selecionar texto em qualquer app + askAI: IA responde com base na seleção
- [ ] Sem seleção: askAI funciona normalmente (sem contexto extra)
- [ ] Clipboard original é restaurado após captura da seleção
- [ ] Contexto selecionado persiste no primeiro turno da conversação
