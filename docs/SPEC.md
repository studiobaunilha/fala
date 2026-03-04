# Sussurro — Especificações do Produto (v1)

## 1. Visão Geral do Produto
O **Sussurro** é uma ferramenta nativa de transcrição e pós-processamento de áudio para macOS (focada em Apple Silicon). Desenvolvida sem necessidade de nuvem para a transcrição central, ela garante máxima privacidade e performance, ideal para profissionais que lidam com informações sensíveis (advogados, médicos, jornalistas, executivos).

## 2. Proposta de Valor
- **100% Offline no Core:** A transcrição de áudio ocorre inteiramente de forma local na máquina (via Neural Engine), garantindo que dados de voz nunca sejam enviados a servidores de terceiros.
- **Integração Fluida (System-wide):** O usuário dita em qualquer lugar do SO ou transcreve arquivos locais, com o texto final sendo inserido magicamente onde o cursor estiver.
- **Pós-Processamento com IA Inteligente:** Após a transcrição bruta, o texto pode passar por LLMs (locais ou via API) para formatação, limpeza, resumo, ou geração de código, poupando trabalho manual de edição.

---

## 3. Principais Funcionalidades

### 1. Modos de Uso
- **Ditado (Tempo Real):** Ativado por um atalho global customizável. O usuário segura a tecla para gravar (push-to-talk). Ao soltar, o áudio é transcrito, formatado pela IA (opcional) e o texto é colado automaticamente no campo ativo.
- **Transcrição de Arquivos (Batch):** O usuário seleciona arquivos de áudio locais. O sistema transcreve o arquivo todo em background.
  - *Diarization:* Identifica automaticamente em transcrições de arquivos as trocas de locutores e formata as respostas via LLM (ex: Locutor 1, Locutor 2).

### 2. Motores de Transcrição
O aplicativo oferece suporte dual-engine, permitindo adequação entre performance e flexibilidade:
- **Whisper (via WhisperKit - MLX):** Solução robusta da OpenAI otimizada para Apple Silicon. Aceita controle paramétrico (*Accuracy vs Speed*) e requer downloads locais pesados para alta precisão (large-v3, medium, etc).
- **Parakeet (via FluidAudio):** Motor de transcrição alternativo e leve da FluidInference para inferência imediata e incrivelmente rápida sem download de modelos massivos da HuggingFace.

### 3. Pós-Processamento Intensivo com LLM (Inteligência Artificial)
O texto bruto pode ser roteado para LLMs para formatação. A aplicação atua rigidamente para que a IA não seja um "assistente conversacional", mas sim um utilitário cego e invisível.
- **Provedores Suportados (Híbrido Nuvem/Local):**
  - MLX Local (*100% Offline e Privado*)
  - Google Gemini API
  - OpenAI GPT API
  - Apple Intelligence (via API Nativa)
  - [Limpar & Formatar] Arruma vírgulas, pontos e remove gaguejos.
  - [Resumir] Entrega apenas os tópicos centrais falados.
  - [Traduzir] Translada dinamicamente texto em PT-BR (ou outro idioma) para Inglês de forma nativa.
  - [Desenvolvedor] Entende instruções de código contextualizado.
  - [Diarization] Identifica múltiplas vozes em arquivos (ex: Locutor 1, Locutor 2) via regras de prompt.

### 4. Gestão de Vocabulário e Atalhos
- **Filtro de Dicionário Automático:** O sistema possui um sistema de *Replacement Rules* (Regras de Substituição). Qualquer termo identificado no áudio pode ser automaticamente substituído (Case-Insensitive) antes mesmo do pós-processamento (ex: "Jira" ➔ "JIRA", "píar" ➔ "PR").

---

## 4. Arquitetura e Tecnologia (Stack)
- **Plataforma:** macOS 14.0+
- **Linguagem / UI:** Swift 6.0 / SwiftUI (Arquitetura orientada a Actors, MVVM)
- **Integração Local:** MenuBar Extra (ícone de bandeja).
- **Dependências Chave:**
  - `WhisperKit` (Transcrição offline baseada em Transformers via CoreML)
  - `FluidAudio` (Transcrição alternativa com suporte a Parakeet)
  - `mlx-swift-lm` (Inferência nativa de LLMs usando M-series Unified Memory)
  - `KeyboardShortcuts` (Gestão de atalhos globais no macOS)

## 5. Permissões do Sistema Operacional
- `NSMicrophoneUsageDescription`: Gravação de voz local do usuário.
- `Accessibility (Acessibilidade)`: Necessário para a API `CGEventPost` gerenciar o clipboard dinamicamente e efetuar a injeção (colagem `Cmd+V`) do texto transcrito nas aplicações nativas focadas.
