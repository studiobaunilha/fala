# Diagnóstico: Travamentos nas Transcrições — Fala v1.9

**Data da investigação:** 2026-03-16  
**Versão do app:** 1.9 (build 19)

---

## O que foi verificado

| Fonte | Resultado |
|-------|-----------|
| `log show` (OSLog `dev.fala.app`) | **Vazio** — logs não retidos após sessão |
| `~/Library/Logs/DiagnosticReports/` | Sem hang reports ou spin dumps do Fala |
| `NSLog [Fala]` no unified log | **Vazio** — não retido |
| `tests.log`, `out.log` | Apenas saída de build/testes, sem logs de runtime |
| UserDefaults `dev.fala.app` | `ProfilingEnabled = 1` (profiler de dictation ativo) |

> [!NOTE]
> Os logs OSLog de nível `notice` e os `NSLog` do app não são retidos entre sessões no sistema — a única forma de capturá-los é via **Console.app em tempo real** ou exportar o diagnóstico pela UI (Ajustes → Suporte → Exportar Diagnóstico).

---

## Configuração Ativa do App

```
transcriptionEngine = parakeet    ← motor de transcrição ativo
transcriptionLanguage = pt
llmProvider = mlx
mlxModel = mlx-community/Qwen3-4B-4bit
selectedDictationTemplate = "Apenas Transcrever"  ← sem LLM (good)
forceWhisperNeuralEngine = false
ProfilingEnabled = 1  ← profiler de dictation ativo
```

---

## Hipóteses de Travamento (Ordenadas por Probabilidade)

### 🔴 Hipótese 1: Parakeet / FluidAudio travando no CoreML/ANE

O `ParakeetTranscriber` chama `mgr.transcribe()` sem timeout:

```swift
// ParakeetTranscriber.swift:78
let result = try await mgr.transcribe(samples, source: .microphone)
```

O `AsrManager` (FluidAudio) usa CoreML com ANE. Em Mac Mini com chip Apple Silicon, o ANE pode ficar num estado de espera indefinida quando:
- Outro processo está usando o ANE simultaneamente
- O modelo CoreML ainda está compilando/otimizando na primeira carga
- O `AsrManager.initialize()` trava antes de completar

**Impacto:** A etapa de transcrição fica suspensa indefinidamente sem mecanismo de cancelamento.

---

### 🟠 Hipótese 2: MLX (Qwen3-4B) travando no carregamento/geração

O `MLXModelCache.generate()` chama `session.respond()` sem timeout:

```swift
// MLXModelManager.swift:282
return try await session.respond(to: userText)
```

O modelo Qwen3-4B tem ~2.3GB. Em Mac Mini, o primeiro carregamento pode travar se:
- Memória sob pressão (processo de swap)
- Framework MLX encontra inconsistência no arquivo `.safetensors`
- GPU/ANE saturado por outro processo

**Mitigação existente:** `selectedDictationTemplate = "Apenas Transcrever"` — portanto MLX **não está sendo chamado** na dictation normal. Mas seria usado em Batch com template LLM.

---

### 🟡 Hipótese 3: AudioConverter.toFloat16k() bloqueando

```swift
// DictationMode.swift:182-184
let samples = try await profiler.measure(.audioConversion) {
    try await Task.detached {
        try AudioConverter.toFloat16k(from: audioURL)
    }.value
}
```

Usa `Task.detached` corretamente, mas se o arquivo de áudio estiver corrompido ou muito longo, o `AudioConverter` pode não completar.

---

### 🟡 Hipótese 4: loadIfNeeded() do Parakeet na primeira chamada

```swift
// ParakeetTranscriber.swift:37-46
let task = Task.detached { [weak self] in
    let downloaded = try await AsrModels.downloadAndLoad(version: .v3)
    let mgr = AsrManager()
    try await mgr.initialize(models: downloaded)
    ...
}
```

Se o modelo precisa ser compilado via CoreML na primeira vez, `initialize()` pode levar 30-90 segundos ou mais — aparecendo como travamento.

---

## Como Capturar Logs para Diagnóstico Real

### Método 1: Console.app em tempo real
1. Abrir **Console.app**
2. Filtrar por `dev.fala.app` ou `Fala`
3. Reproduzir o travamento
4. Exportar os logs

### Método 2: Profiler de Dictation (já ativo!)
Como `ProfilingEnabled = 1` está setado, execute via terminal:

```bash
log stream --predicate 'subsystem == "dev.fala.app"' --level debug --style syslog
```

Em outro terminal, use o app e reproduza o travamento. Os timings de cada etapa aparecerão em tempo real.

### Método 3: Exportar Diagnóstico do App
Ajustes → Suporte → Exportar Diagnóstico  
(Inclui as últimas 50 transcrições com timings detalhados por etapa)

---

## O Que Analisar nos Logs

Quando conseguir capturar, procure por:

```
[Fala] Dictation timing template=... engine=parakeet ...
  → transcription=XXXX  ← etapa que mais demora
  → total=XXXX
  → gap=XXXX  ← tempo não contabilizado (possível travamento aqui)
```

Se `transcription=` for muito alto (>10s) ou o log nunca aparecer → **Hipótese 1**  
Se o log aparece com `total` alto mas `transcription` baixo → **outro stage**

---

## Recomendações Imediatas

1. **Capturar logs em tempo real** via `log stream` (ver acima) na próxima vez que o travamento ocorrer
2. **Verificar se o Parakeet precisa recompilar o modelo CoreML** — na próxima instalação ou após update do macOS, o CoreML recompila modelos, o que pode causar "travamentos" de 1-5min
3. **Considerar timeout** no `ParakeetTranscriber.transcribe()` — adicionar `withTimeout` de 30-60s
4. **Verificar memória** durante o travamento com Activity Monitor — se RAM swap estiver ativo, é provável causa do hang no Parakeet/MLX
