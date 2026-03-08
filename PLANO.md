# Fala - Plano

Este e o unico plano ativo do repositorio.

Ele consolida apenas trabalho ainda em aberto, com base em:

- commits ja entregues no Git ate `c790194`
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
- editor unificado de prompts
- fila de varios arquivos
- empacotamento e release
- batch sem dependencia externa de `ffmpeg`

O backlog aberto ficou reduzido a cinco frentes principais, mais um bloco curto de acabamento.

## Agora

### 1. Limpeza final dos Ajustes e remocao completa de diarization

**Motivo**

Ainda existem residuos de diarization na aplicacao e tambem bugs visuais no layout dos Ajustes que passam sensacao de interface quebrada.

**Definicao de pronto**

- remover diarization completamente do produto
- remover qualquer copy, toggle, estado, logica, configuracao, teste e referencia residual ligada a diarization
- esconder o prompt global de sistema sempre que o provedor efetivo selecionado for Apple Intelligence
- corrigir o layout dos Ajustes para que o conteudo da coluna direita respeite a area util da janela sem clipping ou scroll incorreto
- corrigir o painel lateral para que os cantos, limites e bordas respeitem o container da janela inteira
- cobrir as correcoes com testes de regressao e validacao real da UI empacotada

### 2. Investigacao de performance e cancelamento na transcricao de arquivos

**Motivo**

Ainda existe percepcao de atraso antes da transcricao comecar de fato, e o cancelamento ainda precisa ficar mais responsivo no fluxo batch.

**Definicao de pronto**

- instrumentar o pipeline inteiro de batch: selecao, warmup, preparo, conversao, abertura do arquivo, transcricao e pos-processamento
- identificar o gargalo dominante em arquivo WAV e em arquivo nao WAV
- tornar o cancelamento imediato ou claramente bounded nas etapas longas
- ajustar a UI para refletir o estagio real sem ambiguidade
- adicionar testes de regressao para o caminho cancelado e para o caminho otimizado

### 3. Investigacao de variacao de latencia no ditado rapido

**Motivo**

O caminho rapido de ditado ainda apresenta variacao perceptivel em alguns cenarios, mesmo quando o runtime deveria estar quente.

**Definicao de pronto**

- medir cold path e warm path do fluxo de ditado
- localizar o ponto que causa travadas ocasionais antes da insercao final
- corrigir a principal fonte de variacao sem degradar confiabilidade
- cobrir a regressao com testes automatizados e validacao real de build

## Proximo

### 4. Streaming Whisper / preview vivo

**Motivo**

Continua sendo a proxima expansao funcional relevante e ainda depende de spike tecnico antes de implementacao final.

**Definicao de pronto**

- definir arquitetura do preview incremental
- garantir que preview nao polua a insercao final
- evitar texto instavel ou piscando no alvo
- cobrir o fluxo com testes de regressao do processamento incremental

### 5. Multiplos modos personalizados

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
