# Fala

![Fala](./MyIcon.iconset/icon_128x128.png)

O **Fala** é uma ferramenta nativa, unificada e privada de transcrição de áudio e ditado inteligente para macOS. Foi construída do zero para **Apple Silicon (M1 ou superior)**, focando em entregar o máximo de performance, privacidade e utilidade sem depender de serviços externos na nuvem.

Seja você um advogado analisando depoimentos, um médico documentando diagnósticos, ou um executivo lidando com reuniões confidenciais: seus áudios **nunca saem do seu Mac**.

---

## 1. O que o Fala resolve?
Esqueça gravar áudios em um app, exportar, subir no navegador, esperar a transcrição e depois colar no ChatGPT para arrumar a pontuação.

Com o Fala, você tem um fluxo mágico e contínuo:
1. **Dite em qualquer lugar:** Segure um atalho no teclado em qualquer aplicativo (Word, Slack, Mail, Xcode). Fale naturalmente. Ao soltar a tecla, o texto digitado magicamente aparece formatado sob o seu cursor.
2. **Basta arrastar:** Solte um áudio (ou vídeo) gravado. O Fala transcreve e te entrega o texto pronto para revisar, resumir ou exportar em segundos.

## 2. Principais Funcionalidades

### 1. 100% Offline e Privado no seu Mac
* Utiliza o Motor Apple Neural Engine em conjunto com as melhores bibliotecas (`WhisperKit` e `FluidAudio`) para inferência local. Você não paga taxas por minuto de áudio ou mensalidades absurdas.
* Compatibilidade testada em toda a linha **Apple Silicon (M1, M2, M3, M4)**.

### 2. Modos de Uso Inteligentes
* **Ditado (Tempo Real):** Atalho global (*Push-to-talk*). Pressionou, falou, soltou, colou. O texto é inserido nativamente onde o cursor estiver focado.
* **Batch (Arquivos):** Transcreva gravações de reuniões, aulas, entrevistas ou vídeos. Suporta vários formatos (`.mp3`, `.m4a`, `.wav`, etc).

### 3. Pós-processamento com Inteligência Artificial
Ninguém gosta de ler transcrições cheias de "éhhh", "hmmm" e pontuação quebrada. O Fala roteia o texto bruto para Modelos de Linguagem (Locais via MLX ou via API como Gemini e OpenAI) para limpar a sujeira.
* [Limpar & Formatar:] Arruma gramática e remove vícios de linguagem.
* [Resumir:] Extrai direto o assunto e tópicos chaves do áudio.
* [Traduzir:] Dite em Português e o texto será inserido em Inglês.
* [Desenvolvedor:] Entende instruções de código contextualizado.

### 4. Controle Total na sua Mão
* **Acurácia vs Velocidade:** Ajuste fino sobre o motor Whisper (via *Greedy Decoding*). Otimize caso precise de transcrições instantâneas ou extremamente apuradas.
* **Auto-Substituição:** Crie suas regras de dicionário. ("píar" vira "PR", "Jira" vira "JIRA"). 
* **Prompt Global Hakeável:** Você quem manda na IA. Se não gostar do estilo de formatação do Fala, você pode editar o Prompt de Sistema raiz.

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
