# Plano de Funcionalidades — Fala

> Documento vivo de acompanhamento. Marque `[x]` conforme concluir cada item.

---

## Feature A — Selection + AI Command ✅

Selecionar texto + atalho do Fala → enviar comando de IA sobre a seleção.

### A1. Comando por voz (hold)
- [x] Capturar seleção via `SelectionCapture` (Cmd+C) ao pressionar atalho
- [x] Detectar texto selecionado → entrar em modo `.selectionCommand`
- [x] Gravar comando de voz enquanto segura o atalho
- [x] Enviar `[seleção] + [comando]` ao LLM com prompt dedicado
- [x] Inserir resultado via Cmd+V (substitui seleção)
- [x] HUD âmbar indicando modo seleção

### A2. Comando digitado (quick tap)
- [x] Detectar toque rápido (<400ms) vs hold
- [x] Abrir `SelectionCommandView` — painel flutuante próximo ao cursor
- [x] Campo de texto + preview da seleção (60 chars)
- [x] Enter → envia ao LLM, Escape → cancela
- [x] `KeyablePanel` para receber teclado sem roubar foco do app
- [x] Race condition corrigida (`isRecording` setado antes do await)

### A3. Preview do resultado
- [x] Toggle `selectionPasteDirectly` em `AppConfig` / `AppSettings`
- [x] Menu bar: "Colar resultado direto" (checkmark)
- [x] Ajustes → Geral: seção "Comportamento de IA"
- [x] `SelectionResultView` — painel read-only com botão Colar (Enter)
- [x] `insertOrPreviewResult()` centraliza lógica para voz e digitado
- [x] 4 chaves L10n (pt/en/es)

### A4. HUD pill redesenhado
- [x] Formato pill com `continuousCornerRadius`
- [x] Waveform animado durante gravação
- [x] `ultraThinMaterial` + gradientes + design tokens do projeto

### A5. Release
- [x] Commits atômicos (06a74e5, 413ed56, eeace75, fe3626b)
- [x] Release v1.10 (build 20) — notarizada + publicada

---

## Feature B — QuickEdit pós-resultado

Após a IA processar e colar o resultado (voz ou digitado), o painel permanece
visível por alguns segundos permitindo um segundo comando rápido — "agora
reformata", "mais formal", "traduz para inglês", etc.

Funciona como uma **continuação natural** do fluxo que já existe: o resultado
aparece no `SelectionResultView` (ou é colado direto), e o painel se transforma
num campo de input por ~5s antes de sumir.

### B1. Painel pós-inserção
- [x] Após colar resultado, reabrir/manter o painel flutuante por ~5s
- [x] Mostrar campo de texto "Quer ajustar?" com o resultado como contexto
- [x] Timer visual (barra de progresso sutil ou fade-out gradual)
- [x] Clicar/digitar → cancela o timer, painel permanece
- [x] Ignorar → painel desaparece após timeout
- [x] Escape → fecha imediatamente

### B2. Fluxo de refinamento
- [x] Usuário digita segundo comando → LLM recebe `[resultado anterior] + [novo comando]`
- [x] Resultado substitui o texto que acabou de ser colado (Cmd+A/Cmd+V ou re-select)
- [x] Pode encadear N refinamentos (painel reaparece após cada um)
- [x] Respeitar toggle `selectionPasteDirectly` (preview vs colar direto)

### B3. Integração com fluxos existentes
- [x] Reutilizar `SelectionCommandView` / `SelectionCommandController`
- [x] Funciona tanto no fluxo de voz (hold) quanto no digitado (quick tap)
- [x] Considerar se aplica também ao modo Raw/Translate (sem seleção)

### B4. Testes e qualidade
- [x] Testes unitários para o fluxo de refinamento
- [x] `make check` passando (0 lint, todos os testes)
- [x] Chaves L10n para textos novos

### B5. Release
- [x] Commit atômico
- [x] Release com bump adequado

---

## Feature C — Screenshot + AI Command

Toque rápido **sem texto selecionado** → ativa captura de tela (estilo Cmd+Shift+4).
O screenshot vira contexto visual para uma pergunta de voz ou digitada ao LLM.

Exemplo: selecionar uma área de um chat → perguntar "o que essa pessoa quis dizer?"
→ LLM com visão analisa a imagem e responde.

### C1. Captura de tela
- [ ] Quick tap sem seleção → invocar `screencapture -i` (seleção interativa)
- [ ] Salvar screenshot em diretório temporário
- [ ] Detectar cancelamento (Escape) vs captura concluída
- [ ] Exibir preview pequeno no painel flutuante após captura

### C2. Fluxo de pergunta
- [ ] Após captura, abrir painel de comando (voz ou digitado)
- [ ] Usuário faz a pergunta sobre a imagem
- [ ] Enviar imagem + pergunta ao LLM com suporte a visão
- [ ] Resultado aparece no painel de resultado (respeitando toggle paste/preview)

### C3. Suporte a modelos com visão
- [ ] Adicionar flag `supportsVision: Bool` ao modelo de configuração de LLM
- [ ] Marcar quais providers/modelos suportam imagens (Gemini, GPT-4o, etc.)
- [ ] Se modelo ativo não suporta visão → mostrar aviso e sugerir trocar
- [ ] Apple Intelligence local (MLX) provavelmente não suporta → desabilitar

### C4. Integração nas APIs de LLM
- [ ] Adaptar `llmResponse()` para aceitar imagem opcional (`Data?` / `URL?`)
- [ ] Gemini: enviar como `inlineData` (base64) na API
- [ ] OpenAI: enviar como `image_url` com base64 data URI
- [ ] Prompt ajustado: "Analise esta imagem e responda à pergunta do usuário"

### C5. Testes e qualidade
- [ ] Testes unitários para detecção de seleção vazia + screenshot flow
- [ ] `make check` passando
- [ ] Chaves L10n para textos novos

### C6. Release
- [ ] Commit atômico
- [ ] Release com bump adequado

---

## Feature D — Vocabulário Pessoal (futuro)

Aprender correções automaticamente quando o usuário edita o texto recém-colado.

### D1. Detecção de edição
- [ ] Monitorar via Accessibility API se o texto muda nos ~5s após inserção
- [ ] Comparar texto original vs editado (diff)

### D2. UI de aprendizado
- [ ] HUD discreto "Aprender correção?" com as duas versões
- [ ] Confirmar → persiste em `replacementRules`
- [ ] Rejeitar → descarta

### D3. Integração
- [ ] Reutilizar UI existente de Regras de Substituição nos Ajustes
- [ ] Testes unitários
- [ ] Release

---

## Referência rápida

| Feature | Status | Release |
|---------|--------|---------|
| A — Selection + AI Command | ✅ Completa | v1.10 |
| B — QuickEdit pós-resultado | ⏸️ Pausada | — |
| C — Screenshot + AI Command | 🔲 Planejada | — |
| D — Vocabulário Pessoal | 🔲 Futuro | — |
