# Fala - Plano

Este e o unico plano ativo do repositorio.

Ele consolida apenas trabalho ainda em aberto, com base em:

- commits ja entregues no Git
- backlog anterior
- notas em `docs/brainstorming/`

O que ja foi entregue nao reaparece aqui. O historico fica no Git e no `CHANGELOG.md`.

## Guardrails

Toda entrega deste plano precisa respeitar estes gates:

- `make lint`
- `make test`
- `make check`
- build debug verde
- build release verde sempre que tocar fluxo distribuido, onboarding, warmup, menu bar, batch ou runtime principal
- `make test-mlx` sempre que tocar catalogo MLX, download MLX, warmup MLX ou pos-processamento MLX
- TDD e testes de regressao guiados por risco real
- nenhuma mudanca de performance sem instrumentacao suficiente para comparar antes e depois
- nenhum fallback silencioso em fluxos principais

## Estado atual

Hoje, o que estava em P0 e P1 ja foi fechado.

Isso inclui, entre outros pontos:

- licenca e relaunch
- onboarding e readiness
- warmup principal
- catalogo e selecao de modelos
- reorganizacao dos Ajustes
- restauracao do chrome nativo da janela de Ajustes
- editor unificado de prompts
- fila de varios arquivos
- empacotamento e release
- batch sem dependencia externa de `ffmpeg`

O backlog aberto ficou reduzido a quatro frentes principais, mais um bloco curto de acabamento.

## Checkpoint de retomada

- **Frente 1 - batch / performance e cancelamento**: em andamento; esta retomada fechou instrumentacao por estagio, cancelamento mais honesto, `--profile`, `--prepare-only`, entrypoint async no CLI, regressao E2E com `AAC/M4A` gerado pela stack da Apple e baseline frio para `WAV`
- **Frente 2 - latencia no ditado rapido**: nao iniciada nesta retomada; continua apenas planejada
- **Frente 3 - streaming Whisper / preview vivo**: nao iniciada nesta retomada; continua apenas planejada
- **Frente 4 - multiplos modos personalizados**: nao iniciada nesta retomada; continua apenas planejada
- **Backlog curto**: sem avancos nesta retomada

## Agora

### 1. Investigacao de performance e cancelamento na transcricao de arquivos

**Status**

- em andamento

**Motivo**

Ainda existe percepcao de atraso antes da transcricao comecar de fato, e o cancelamento ainda precisa ficar mais responsivo no fluxo batch.

**Ja avancado**

- batch agora distingue preparo do motor, transcricao e pos-processamento na UI
- preparo de audio do batch saiu do `MainActor`, reduzindo travamento perceptivel antes da transcricao comecar
- cancelamento passou a interromper a task de processamento e a respeitar cancelamento durante a transcricao incremental
- cancelamento durante preparo de audio agora aborta o pipeline antes do warmup/transcribe e limpa arquivo temporario parcial
- cada execucao batch agora registra tempos de preparo de audio, preparo do motor, transcricao, pos-processamento e total
- a telemetria de batch agora diferencia `WAV` em fast path vs conversao real e tambem marca se o modelo ja estava `ready`, `loading` ou `cold`
- o CLI `fala transcribe` agora aceita `--profile` para emitir o mesmo breakdown de tempos fora da UI e facilitar comparacao reproduzivel entre `WAV` e `nao WAV`
- o CLI de batch agora roda com entrypoint async sem bloquear em semaforo e tambem aceita `--prepare-only` para medir apenas a normalizacao de audio
- regressao end-to-end adicionada para exercitar o executavel construido com `AAC/M4A` gerado pela propria stack da Apple e garantir que `--prepare-only` para antes do warmup
- regressao adicionada para estado `preparingModel`, cancelamento durante preparo de audio, limpeza de temporario cancelado e captura de metricas
- baseline frio medido no app empacotado para `WAV` ja normalizado: preparo ~`0.000s`, warmup do modelo ~`7.386s`, transcricao ~`0.620s`, total ~`8.024s`
- validacao ja rodada com `make check`, build debug e build release

**Ainda falta**

- fechar uma amostra `nao WAV` representativa e estavel para comparacao real com o baseline `WAV`; o fixture sintetico `AAC/M4A` gerado por `ffmpeg` nao e uma boa referencia aqui, porque a propria stack nativa da Apple (`ExtAudioFile` e `afconvert`) o rejeita com `cfmt/fmt?`
- decidir se o proximo corte principal deve atacar warmup/pool do motor no caminho `WAV` ou ampliar compatibilidade de ingestao para `M4A/AAC` externos que fujam do conjunto validado pela stack da Apple
- revisar se ainda existe algum trecho longo sem cancelamento bounded no caminho de batch
- avaliar se faz sentido atacar cancelamento mais fino dentro da propria conversao de audio, sem trocar estabilidade por responsividade artificial

**Retomar daqui**

- usar `fala transcribe <arquivo> --profile --prepare-only` com um `M4A/AAC` real de referencia do mundo real, por exemplo uma gravacao externa ou Voice Memos, em vez de depender do fixture sintetico do `ffmpeg`
- comparar esse `nao WAV` com o baseline atual do `WAV`; hoje o caminho frio de `WAV` mostra que o gargalo dominante ja medido e o warmup do modelo, nao o preparo de audio
- depois disso, repetir o fluxo completo com modelo frio vs aquecido para decidir se o proximo corte mexe primeiro em warmup/pool ou em compatibilidade de ingestao externa

**Definicao de pronto**

- usar a instrumentacao nova para fechar diagnostico comparativo entre WAV e nao WAV
- eliminar o principal gargalo identificado sem perder estabilidade
- manter cancelamento imediato ou claramente bounded nas etapas longas
- preservar a UI refletindo o estagio real sem ambiguidade
- manter regressao cobrindo caminho cancelado e caminho otimizado

### 2. Investigacao de variacao de latencia no ditado rapido

**Status**

- nao iniciado nesta retomada

**Motivo**

O caminho rapido de ditado ainda apresenta variacao perceptivel em alguns cenarios, mesmo quando o runtime deveria estar quente.

**Definicao de pronto**

- medir cold path e warm path do fluxo de ditado
- localizar o ponto que causa travadas ocasionais antes da insercao final
- corrigir a principal fonte de variacao sem degradar confiabilidade
- cobrir a regressao com testes automatizados e validacao real de build

## Proximo

### 3. Streaming Whisper / preview vivo

**Status**

- nao iniciado nesta retomada

**Motivo**

Continua sendo a proxima expansao funcional relevante e ainda depende de spike tecnico antes de implementacao final.

**Definicao de pronto**

- definir arquitetura do preview incremental
- garantir que preview nao polua a insercao final
- evitar texto instavel ou piscando no alvo
- cobrir o fluxo com testes de regressao do processamento incremental

### 4. Multiplos modos personalizados

**Status**

- nao iniciado nesta retomada

**Motivo**

Hoje o produto ainda suporta apenas um modo customizado.

**Definicao de pronto**

- permitir criar, editar, ordenar e remover mais de um modo personalizado
- reaproveitar a UI e a logica de prompts ja existentes
- migrar configuracoes antigas sem quebrar usuarios atuais
- cobrir persistencia, migracao e fluxo principal com testes

## Backlog curto

Estes itens continuam abertos, mas ficam abaixo das cinco frentes acima:

- ocultar `Traduzir para Ingles` quando o idioma efetivo da aplicacao ja for ingles
- revalidar se `mlx-community/Qwen3.5-4B-MLX-4bit` merece entrar no catalogo curado; so promover depois de smoke test real

## Estacionado para depois

Nao entra no ciclo atual, mas continua registrado como direcao futura:

- gravacao de reunioes com audio do sistema + microfone, com timeline consolidada
- exploracao de UI persistente para esse fluxo, incluindo alternativa no notch/menu bar se fizer sentido
- exposicao futura de API ou automacao local do app
