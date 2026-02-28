# Sussuro

Sistema unificado de transcrição de áudio e ditado inteligente, ultra-otimizado para processadores Apple Silicon (M4).

## 1. Visão Geral
Substituir ferramentas fragmentadas (Handy, MacWhisper) por um motor unificado, local e open-source que utiliza o FFmpeg 8.0 para manipulação de áudio, Whisper.cpp para transcrição via Metal (GPU) e Ollama (Llama 3.2) para pós-processamento e correção de texto.

## 2. Requisitos Técnicos
- **OS:** macOS (Apple Silicon M4).
- **Audio Engine:** FFmpeg 8.0 (nativo com Apple Neon/AudioToolbox).
- **Transcription Engine:** `whisper.cpp` (Metal enabled).
- **LLM Engine:** `Ollama` (local).
- **Modelos Sugeridos:**
  - Whisper: `ggml-large-v3-turbo` (Velocidade e precisão).
  - LLM: `llama3.2:3b` (Correção gramatical e formatação técnica).

## 3. Funcionalidades Principais

### A. Transcrição de Arquivos (Modo Batch)
- Entrada: Arquivos `.m4a`, `.mp3`, `.wav`, `.mp4`.
- Processo: 
  1. Extração/Normalização via FFmpeg (16kHz, mono).
  2. Transcrição acelerada por GPU.
  3. Pós-processamento opcional via LLM para limpeza de "gargalos" de fala e formatação Markdown.
- Saída: Arquivo `.txt` ou `.md` com o mesmo nome do original.

### B. Ditado Inteligente (Modo Real-time replacement)
- Funcionamento: Atalho de teclado inicia a gravação.
- Diferencial: O texto transcrito passa por uma "limpeza rápida" (LLM) antes de ser inserido no sistema via AppleScript (`keystroke`), removendo vícios de linguagem e corrigindo termos técnicos em milissegundos.

## 4. Estrutura do Projeto (Sugestão)
- `bin/susurro`: Script principal (Python ou Bash).
- `config/prompts.json`: Prompts do LLM para diferentes contextos (Arquitetura de Software, Reunião, Notas).
- `models/`: Links simbólicos ou gerenciamento dos modelos `.bin`.

## 5. Próximos Passos (Desenvolvimento)
1. Criar script de bootstrap para garantir dependências (`brew install ffmpeg whisper-cpp ollama`).
2. Desenvolver o script de transcrição de arquivo com suporte a parâmetros.
3. Implementar a lógica de inserção de texto via AppleScript para o modo ditado.
4. Refinar o prompt de correção para o contexto do Sussuro.