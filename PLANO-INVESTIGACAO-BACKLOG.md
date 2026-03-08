# Fala — Backlog de Execucao

## Objetivo

Este documento define o backlog ativo do Fala para v1 e v1.x.

Ele existe para responder, com clareza:

- o que esta decidido;
- o que ja foi entregue;
- o que ainda precisa ser feito;
- em que ordem vamos executar.

Nao registra historico, indecisao antiga, tentativa descartada ou anotacao transitoria.

## Guardrails de qualidade

Toda entrega deste backlog deve respeitar estes gates:

- `make lint`
- `make test`
- `make check`
- build debug verde
- build release verde sempre que a entrega tocar fluxo distribuido, onboarding, warmup, menu bar ou runtime principal
- `make test-mlx` sempre que a entrega tocar MLX, catalogo MLX, loader MLX, warmup MLX, download MLX ou pos-processamento MLX
- testes novos guiados por risco e regressao real
- nenhuma UI nova sem tokens, componentizacao e reaproveitamento coerente com o Design System do projeto
- nenhum fallback silencioso em fluxos principais
- nenhuma alteracao de performance sem instrumentacao suficiente para validar ganho ou regressao

## Decisoes fechadas

- Bugs e confiabilidade tem prioridade sobre expansoes de escopo.
- O produto de lancamento precisa ser previsivel, rapido e transparente antes de ganhar novas capacidades.
- O catalogo MLX continua curado e validado pelo app; o fluxo principal nao expoe repo customizado livre.
- O item `mlx-community/Qwen3.5-4B-MLX-4bit` continua fora do catalogo de texto enquanto nao houver validacao explicita para uso LLM textual no runtime atual.
- A bandeja nao deve representar warmup em background como se fosse download real ou bloqueio do usuario.
- Pos-processamento com MLX deve ter comportamento binario:
  - ou processa;
  - ou bloqueia com erro explicito e estado coerente.
- O fluxo de licenca no macOS e tratado como acesso ao Keychain, nao como selecao de arquivo; o app deve restaurar esse estado com snapshot unico e sem leituras redundantes no mesmo launch.
- Builds usados para validar licenciamento localmente precisam de identidade de assinatura estavel; assinatura ad hoc baseada em `cdhash` nao e aceitavel como fluxo padrao para esse caso.
- A acao `Reiniciar agora` so pode existir quando o relaunch for verificavel; se isso nao puder ser garantido, a interface deve orientar fechamento e abertura manual com copy honesta.
- O fluxo de Whisper deve priorizar reuso e warmup corretos antes de qualquer redesign maior de UX.
- O redesign de escolha de modelos deve convergir para componentes reutilizaveis, nao gerar mais uma interface paralela.
- Todo prompt usado pelo app deve caminhar para um modelo editavel e restauravel pelo usuario, com uma unica linguagem de interface.

## Status atual

### P0 — Confiabilidade e verdade de estado

| Item | Status atual | Definicao de pronto |
| --- | --- | --- |
| Licenca: eliminar prompts repetidos de senha do Keychain `login` | Concluido | O launch deixa de disparar 3-5 pedidos equivalentes para acessar `dev.fala.app.license` nas chaves do `login`; o estado de licenca passa a ser restaurado a partir de um snapshot unico em memoria; token, email e tempo de servidor nao sao relidos em cadeia quando um estado consistente ja foi carregado; o fluxo de build usado para validar licenca deixa de depender de identidade ad hoc instavel; a UX de autorizacao fica objetiva e nao obriga repeticao manual de senha para o mesmo contexto; testes cobrem restauracao paga, trial, migracao legada e falha de acesso ao store seguro. |
| Restart: relaunch confiavel ou fallback honesto | Concluido | Ao confirmar uma mudanca que exige reinicio, o app abre uma nova instancia de forma verificavel e so encerra a instancia atual depois disso; se o relaunch falhar, a UI deixa de prometer reinicio automatico e instrui corretamente fechamento e abertura manual; testes cobrem sucesso, falha e cancelamento. |
| MLX: crash ao concluir download | Concluido | O app nao fecha ao concluir download MLX; updates de progresso nao derrubam a bandeja; eventos de conclusao chegam na main thread; `make check`, `build debug` e `make test-mlx` verdes. |
| Batch: erro de MLX explicito | Concluido | Batch nao ignora mais falha de MLX em silencio; usuario recebe erro ou aviso claro. |
| MLX: refresh em tempo real | Concluido | Tela de modelos MLX reflete progresso e estado sem exigir troca de tela. |
| Bandeja: estado real vs warmup | Concluido | Bandeja separa download real de warmup/preparo; tooltip e simbolo refletem estado real. |
| Whisper: cold start em arquivo | Concluido para v1 | Batch reutiliza recursos e prewarm reduz o cold path principal. |
| Ditado rapido: variacao de latencia | Concluido para v1 | Ditado usa prewarm e reutilizacao suficientes para o caminho principal de v1. |
| Tamanhos errados dos modelos Whisper | Concluido | Tamanhos exibidos deixaram de mentir para o usuario. |

### P1 — UX, simplificacao e base reutilizavel

| Item | Status atual | Definicao de pronto |
| --- | --- | --- |
| Descricao de motores/modelos mais clara | Concluido | Tela de escolha explica Parakeet vs Whisper em linguagem de produto, com recomendacao clara e sem exigir conhecimento tecnico. |
| Padronizacao da UI de catalogo | Concluido para transcricao | Whisper passou a usar o mesmo padrao de catalogo local com card de resumo, linha de acao unica e componentes reutilizaveis; MLX permanece no mesmo modelo visual. |
| Simplificacao do Whisper para modelo unico | Concluido | Usuario escolhe um unico modelo Whisper ativo; migracao preserva configuracoes antigas sem quebrar o app. |
| Editor unico de prompts + Apple editavel | Planejado | Todo prompt relevante pode ser editado, restaurado e exibido pela mesma interface; Apple Intelligence deixa de ser somente leitura. |
| Reorganizacao dos Ajustes | Planejado | Ajustes passam a refletir o modelo mental do produto: motor de transcricao, transcricao de arquivos, IA/LLM e configuracoes da aplicacao. |

### P2 — Expansao funcional

| Item | Status atual | Definicao de pronto |
| --- | --- | --- |
| Fila de varios arquivos | Planejado | Usuario pode selecionar varios arquivos, ver fila, acompanhar progresso e processar em lote com estado consistente. |
| Streaming Whisper / preview vivo | Planejado com spike tecnico obrigatorio | Existe preview progressivo confiavel sem degradar insercao final nem gerar texto instavel no alvo. |
| Multiplos modos personalizados | Planejado | Usuario pode criar e gerenciar mais de um modo customizado sem duplicar UI ou logica de prompts. |

## Entregas ja consolidadas

- readiness e onboarding baseados em estado valido
- warmup coordenado e regras de prontidao centralizadas
- catalogo MLX curado por manifesto
- bloqueio de uso sem modelo local valido
- restart transacional para mudancas que exigem reinicio
- relaunch confiavel com fallback honesto quando o app nao conseguir reabrir sozinho
- restauracao da licenca via snapshot unico de Keychain no mesmo launch
- avisos explicitos para falhas de MLX no batch
- reuso de transcriber no batch e prewarm do fluxo principal
- bandeja separando download real de preparo em background
- validacao de integridade de modelo MLX local antes de considerar o modelo utilizavel
- escolha de motor de transcricao em linguagem de produto
- catalogo Whisper unificado com um unico modelo ativo para ditado e arquivos

## Proxima ordem de execucao

### Fase 2 — Prompts e arquitetura de Ajustes

1. Editor unico de prompts + Apple editavel
2. Reorganizacao dos Ajustes

### Fase 3 — Expansoes

1. Fila de varios arquivos
2. Streaming Whisper / preview vivo
3. Multiplos modos personalizados

## Criterios para avancar de fase

- Nenhum item da fase atual pode depender de correcao posterior de bug conhecido na mesma area.
- Nenhuma fase nova comeca com gates vermelhos.
- Nenhuma simplificacao de UX entra antes do fluxo atual estar estavel no runtime real.

## Resumo executivo

Hoje, o backlog ativo esta assim:

- P0: concluido
- P1: concluido
- P2: planejado para depois da estabilizacao final da v1
