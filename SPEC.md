# Sussurro — Definições Técnicas

## Projeto

**Nome:** Sussurro
**Escopo:** Ferramenta pessoal, sem App Store, sem sandbox
**Plataforma:** macOS 26.1+ (Tahoe), Apple M4
**Repositório:** `/Users/ale/Dev/sussurro`

---

## Linguagem e Toolchain

- **Linguagem:** Swift 6.0
- **Build:** `swift build -c release` (sem Xcode obrigatório)
- **Package manifest:** `swift-tools-version: 6.0`
- **Deployment target:** `.macOS(.v26)`

---

## Dependências (Swift Package Manager)

```swift
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0"),
]
```

---

## Modos de Operação

### Modo 1: Ditado em Tempo Real

**Ativação:** menu bar app (lançado sem argumentos CLI)
**Mecanismo de parada:** push-to-talk — tecla pressionada = gravando, tecla solta = transcreve
**Hotkey padrão:** configurável via `KeyboardShortcuts`

**Pipeline:**
```
keyDown  →  AVAudioEngine.start()  →  [gravando]
keyUp    →  AVAudioEngine.stop()   →  PCM 16kHz Float array
         →  WhisperKit.transcribe()  →  String
         →  NSPasteboard.set(text) + CGEventPost(⌘V)  →  texto inserido no campo focado
```

### Modo 2: Transcrição em Lote (CLI)

**Ativação:** `sussurro transcribe <arquivo> [--format md] [--model large-v3]`
**Entrada suportada:** `.m4a`, `.mp3`, `.wav`, `.mp4`

**Pipeline:**
```
ffmpeg -i <input> -ar 16000 -ac 1 -f wav /tmp/sussurro_tmp.wav
→  WhisperKit.transcribe(audioPath:)
→  grava <mesmo-nome>.txt ou .md no mesmo diretório
```

---

## Componentes Técnicos

| Responsabilidade | Solução |
|---|---|
| Transcrição | WhisperKit (CoreML + Apple Neural Engine) |
| Captura de áudio | `AVAudioEngine` — saída PCM mono 16kHz |
| Conversão de arquivo | FFmpeg 8.0.1 via `Foundation.Process` |
| Hotkey global | `KeyboardShortcuts` (SPM) |
| Inserção de texto | `NSPasteboard.general` + `CGEventPost(⌘V)` — salva/restaura clipboard |
| UI | `SwiftUI MenuBarExtra` — ícone muda por estado |
| Configuração | `Codable` + JSON em `~/.config/sussurro/config.json` |

---

## Modelos de Transcrição

| Modo | Modelo padrão | Override via config |
|------|--------------|---------------------|
| Ditado | `openai_whisper-medium` | sim |
| Batch | `openai_whisper-large-v3-turbo` | sim |

Modelos baixados automaticamente por WhisperKit para `~/.cache/huggingface/`.

---

## Estados da UI (StatusBar)

| Estado | Ícone |
|--------|-------|
| Idle | microfone (inativo) |
| Gravando | microfone + círculo vermelho |
| Transcrevendo | atividade / spinner |

---

## Permissões Necessárias (macOS)

- **Microfone** — `AVAudioEngine` (`NSMicrophoneUsageDescription`)
- **Accessibility** — `CGEventPost` para inserção de texto

Solicitadas na primeira execução. Sem sandbox = sem entitlements adicionais.

---

## Estrutura do Projeto

```
sussurro/
├── Package.swift
├── Sources/
│   └── Sussurro/
│       ├── main.swift                  # Dispatch: menu bar OU CLI batch
│       ├── App/
│       │   └── SussurroApp.swift       # MenuBarExtra + AppDelegate
│       ├── Core/
│       │   ├── AudioEngine.swift       # AVAudioEngine: captura e retorna [Float]
│       │   ├── Transcriber.swift       # WhisperKit wrapper
│       │   └── TextInserter.swift      # Clipboard save → paste → restore
│       ├── Modes/
│       │   ├── DictationMode.swift     # Coordena push-to-talk + transcrição + inserção
│       │   └── BatchMode.swift         # Coordena ffmpeg + transcrição + escrita de arquivo
│       ├── UI/
│       │   └── StatusBarView.swift     # Estado visual do menu bar
│       └── Config/
│           └── AppConfig.swift         # Leitura/escrita de config.json
├── config/
│   └── default-config.json
└── scripts/
    └── install.sh                      # swift build -c release + ln -s para /usr/local/bin
```

---

## Fora do Escopo (MVP)

- LLM / pós-processamento com Ollama
- VAD automático (silêncio detectado — adicionado em iteração futura)
- Múltiplos perfis de contexto para LLM
- Distribuição via App Store ou código assinado
