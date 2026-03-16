# Logging Persistente + Redesign do HUD de Dictation

## Visão Geral

Dois itens independentes:
1. **Logging persistente em modo dev** — gravar logs do Fala em arquivo durante sessões longas de trabalho para investigar travamentos intermitentes
2. **Redesign do HUD de dictation** — remover a barra de ícones de estágios, deixar o HUD em formato pílula e fazer a waveform expressar o estado atual visualmente

---

## Item 1: Logging Persistente em Modo Dev

### O Problema
O `log stream` atual (via `make logs`) só exibe em tempo real. Se o travamento ocorre horas depois, o terminal não está à vista e os logs se perdem.

### Solução
Adicionar um novo target `make logs-save` no Makefile que grava simultaneamente no terminal e em arquivo:

```makefile
logs-save: ## Salva logs do app em arquivo + exibe em tempo real (Ctrl+C para parar)
    @mkdir -p $(HOME)/Desktop/fala-logs
    @LOG_FILE="$(HOME)/Desktop/fala-logs/fala-$$(date +%Y%m%d-%H%M%S).log"; \
        printf "$(GREY)Gravando logs em $$LOG_FILE…$(RESET)\n"; \
        log stream --predicate 'subsystem == "dev.fala.app"' --level debug | tee "$$LOG_FILE"
```

#### Arquivos Modificados

#### [MODIFY] [Makefile](file:///Volumes/MacMini/Home/Dev/fala/Makefile)
- Adicionar target `logs-save` que grava logs em `~/Desktop/fala-logs/fala-YYYYMMDD-HHMMSS.log` e exibe em tempo real via `tee`
- Atualizar `.PHONY` para incluir `logs-save`
- Adicionar instrução no target `dev` sobre como usar `logs-save` durante desenvolvimento

---

## Item 2: Redesign do HUD de Dictation

### O Problema
A barra de ícones (`StageIndicatorRow`) ocupa espaço sem agregar muito visualmente. O usuário quer que a própria waveform transmita o estado.

### Solução
- Remover completamente `StageIndicatorRow` do layout
- Reformatar o HUD para **pílula**: largura mantida (~292), altura reduzida (~80px), cornerRadius aumentado para ≥37 (verdadeira pílula)
- A `WaveformBars` passa a ter **3 modos visuais** baseados no stage:
  - `recording` → barras coloridas animadas (atual, mantido)  
  - `transcribing` → barras que "respiram" em animação suave de processamento (pulsar lento, cor levemente diferente — ciano  frio)
  - `processing` / `inserting` → dots girando ou travel animation horizontal com gradiente diferenciado
  - `done` → fade out (já tratado pelo `dismiss()`)
- O `ConversationTurnBadge` (contador de turns) fica no canto superior direito do HUD como overlay pequeno, sem precisar de linha dedicada

### Arquivos Modificados

#### [MODIFY] [DictationFeedbackView.swift](file:///Volumes/MacMini/Home/Dev/fala/Sources/FalaCore/UI/DictationFeedbackView.swift)
- `DictationFeedbackLayout`: altura → `80`, cornerRadius → `40` (pílula real)
- Remover `StageIndicatorRow` do `body`
- Remover linha `HStack` com `StageIndicatorRow` e `ConversationTurnBadge`
- Mover `ConversationTurnBadge` para overlay no canto superior direito do HUD
- `WaveformBars`: receber `stage: DictationStage` em vez de só `isRecording: Bool`
- Implementar 3 visuais na `WaveformBars`:
  - `.recording` → atual (barras dinâmicas)
  - `.transcribing` → barras fixas de altura média com animação de pulso/breathing (cor ciano)
  - `.processing` / `.inserting` → dots viajando da esquerda para direita (travel animation)

#### [MODIFY] [DictationFeedbackController.swift](file:///Volumes/MacMini/Home/Dev/fala/Sources/FalaCore/UI/DictationFeedbackController.swift)
- Atualizar `panelRect` e `makeTransparentContainer` com as novas dimensões

---

## Verificação

### Testes Unitários Existentes
```bash
make test
```
Os testes de `DictationFeedbackModelTests` não dependem da View — continuarão passando sem mudança.

### Testes Visuais (Manual — via `make dev`)
1. `make dev` — rodar o app em modo debug
2. Pressionar e segurar o atalho de dictation → verificar que o HUD aparece em formato pílula com barras animadas
3. Soltar o atalho → verificar que a waveform muda para o visual de "transcribing" (pulso/breathing)
4. Aguardar inserção → HUD some com fade
5. Verificar que o `ConversationTurnBadge` (se template conversacional) aparece como overlay no canto do HUD

### Teste do Logging
1. `make logs-save` em um terminal
2. `make dev` em outro terminal  
3. Usar o app por alguns minutos
4. Ctrl+C no primeiro terminal
5. Verificar que o arquivo `~/Desktop/fala-logs/fala-YYYYMMDD-HHMMSS.log` existe e tem conteúdo com os timings de dictation
