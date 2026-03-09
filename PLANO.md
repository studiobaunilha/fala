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

O backlog aberto ficou reduzido a quatro frentes principais, mais um bloco curto de acabamento.

## Agora

### 1. Investigacao de performance e cancelamento na transcricao de arquivos

**Motivo**

Ainda existe percepcao de atraso antes da transcricao comecar de fato, e o cancelamento ainda precisa ficar mais responsivo no fluxo batch.

**Ja avancado**

- batch agora distingue preparo do motor, transcricao e pos-processamento na UI
- cancelamento passou a interromper a task de processamento e a respeitar cancelamento durante a transcricao incremental
- cada execucao batch agora registra tempos de preparo de audio, preparo do motor, transcricao, pos-processamento e total
- regressao adicionada para estado `preparingModel`, cancelamento durante preparo e captura de metricas
- validacao ja rodada com `make check`, `make test-mlx`, build debug e build release

**Ainda falta**

- comparar arquivos WAV vs nao WAV com a nova instrumentacao para localizar o gargalo dominante no uso real
- decidir se o proximo corte deve atacar preparo de audio, warmup/pool ou inicializacao do runtime
- revisar se ainda existe algum trecho longo sem cancelamento bounded no caminho de batch

**Definicao de pronto**

- usar a instrumentacao nova para fechar diagnostico comparativo entre WAV e nao WAV
- eliminar o principal gargalo identificado sem perder estabilidade
- manter cancelamento imediato ou claramente bounded nas etapas longas
- preservar a UI refletindo o estagio real sem ambiguidade
- manter regressao cobrindo caminho cancelado e caminho otimizado

### 2. Investigacao de variacao de latencia no ditado rapido

**Motivo**

O caminho rapido de ditado ainda apresenta variacao perceptivel em alguns cenarios, mesmo quando o runtime deveria estar quente.

**Definicao de pronto**

- medir cold path e warm path do fluxo de ditado
- localizar o ponto que causa travadas ocasionais antes da insercao final
- corrigir a principal fonte de variacao sem degradar confiabilidade
- cobrir a regressao com testes automatizados e validacao real de build

## Proximo

### 3. Streaming Whisper / preview vivo

**Motivo**

Continua sendo a proxima expansao funcional relevante e ainda depende de spike tecnico antes de implementacao final.

**Definicao de pronto**

- definir arquitetura do preview incremental
- garantir que preview nao polua a insercao final
- evitar texto instavel ou piscando no alvo
- cobrir o fluxo com testes de regressao do processamento incremental

### 4. Multiplos modos personalizados

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
