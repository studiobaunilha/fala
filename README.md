# Fala

![Fala](./MyIcon.iconset/icon_128x128.png)

O **Fala** é uma ferramenta nativa de transcrição de áudio e ditado inteligente para macOS. Foi construída do zero para **Apple Silicon (M1 ou superior)**, com foco em performance, privacidade e integração fluida com o sistema.

A transcrição principal roda localmente no dispositivo. Recursos opcionais de pós-processamento podem usar modelos locais ou provedores de API configurados pelo usuário.

---

## 1. O que o Fala resolve?
O Fala reduz o atrito entre gravar, transcrever, revisar e reutilizar conteúdo de áudio no macOS.

Fluxos principais:
1. **Ditado em qualquer app:** Segure o atalho global, fale normalmente e solte para transcrever e inserir o texto no campo ativo.
2. **Transcrição de arquivos:** Selecione um áudio ou vídeo local para transcrever, revisar, resumir ou exportar.

## 2. Principais Funcionalidades

### 1. 100% Offline e Privado no seu Mac
* Utiliza o Apple Neural Engine em conjunto com `WhisperKit` e `FluidAudio` para inferência local de transcrição.
* Compatibilidade testada em toda a linha **Apple Silicon (M1, M2, M3, M4)**.

### 2. Modos de Uso Inteligentes
* **Ditado (Tempo Real):** Atalho global (*Push-to-talk*). Pressionou, falou, soltou, colou. O texto é inserido nativamente onde o cursor estiver focado.
* **Batch (Arquivos):** Transcreva gravações de reuniões, aulas, entrevistas ou vídeos. Suporta vários formatos (`.mp3`, `.m4a`, `.wav`, etc).

### 3. Pós-processamento com Inteligência Artificial
O Fala pode encaminhar o texto transcrito para modelos de linguagem, locais via MLX ou remotos via API, para limpeza, formatação e transformação do conteúdo.
* [Limpar & Formatar:] Arruma gramática, pontuação e formatação da transcrição.
* [Resumir:] Extrai direto o assunto e tópicos chaves do áudio.
* [Traduzir:] Dite em Português e o texto será inserido em Inglês.
* [Desenvolvedor:] Entende instruções de código contextualizado.

### 4. Controle Total na sua Mão
* **Acurácia vs Velocidade:** Ajuste fino sobre o motor Whisper (via *Greedy Decoding*). Otimize caso precise de transcrições instantâneas ou extremamente apuradas.
* **Auto-Substituição:** Crie suas regras de dicionário. ("píar" vira "PR", "Jira" vira "JIRA"). 
* **Prompts por modo e provedor:** Ajuste o comportamento dos modos com prompts específicos para o fluxo e o provedor configurado.

---

## 3. Requisitos Técnicos
- **Sistema Operacional:** macOS 14.0 (Sonoma) ou superior.
- **Hardware:** Mac com Processador **Apple Silicon (M1, M1 Pro, M2, M3, M4, etc)**.
- *Nota:* Baixar modelos pesados de LLM ou Whisper (Large-v3) pode requerer >= 16GB de Memória RAM Unificada para máxima fluidez, embora modelos menores (Medium, Parakeet) rodem perfeitamente em 8GB de RAM.

## 4. CLI de Diagnóstico

Para investigar latência na transcrição de arquivos sem depender da UI, o modo batch por linha de comando aceita `--profile`:

```bash
fala transcribe /caminho/para/audio.m4a --profile
```

O comando imprime uma linha com tempos de preparo de áudio, warmup do modelo, transcrição e total, além de indicar se o arquivo entrou em fast path `WAV` ou conversão real.
