# Fala — Plano de Investigacao do Backlog

Documento de trabalho registrado em 7 de marco de 2026.

Este arquivo existe na raiz por solicitacao direta do projeto. Ele nao substitui a documentacao oficial consolidada em `README.md`, `docs/SPEC.md` e `docs/`; trata-se de um plano de investigacao e execucao futura. Decisoes de produto so devem ser promovidas para a documentacao oficial depois de validadas.

## Objetivo

Registrar, com base em leitura do codigo atual e em referencias externas atualizadas, os bugs e melhorias levantados para o Fala, junto com:

- diagnostico tecnico inicial;
- impacto em UX, arquitetura e performance;
- sugestao de como enderecar cada item;
- criterios de validacao;
- riscos e dependencias.

Este documento nao prioriza ainda. A matriz de valor x velocidade sera feita depois.

## Guardrails de qualidade

Qualquer execucao futura deste backlog deve manter estes gates como definicao minima de pronto:

- `make lint`
- `make test`
- `make check`
- build debug verde
- build release verde quando a etapa tocar comportamento distribuido
- cobertura nova guiada por risco e regressao, sem criar mocks complexos quando um teste de integracao ou E2E trouxer mais sinal
- nenhum fluxo novo de UI sem tokenizacao, componentizacao e alinhamento com o Design System ja existente
- nenhuma alteracao estrutural em settings, menu bar, onboarding ou prompts sem validar aderencia ao estilo nativo do macOS

Para investigacoes de performance e crash:

- adicionar instrumentacao com `Logger`/signposts antes de otimizar;
- reproduzir com fixtures reais e tempos comparaveis;
- usar Instruments quando houver suspeita de pico de memoria, cold start ou regressao de latencia.

## Base de investigacao

### Codigo inspecionado

- `Sources/FalaCore/UI/StatusBarController.swift`
- `Sources/FalaCore/App/AppDelegate.swift`
- `Sources/FalaCore/App/WarmupCoordinator.swift`
- `Sources/FalaCore/Core/Transcriber.swift`
- `Sources/FalaCore/Core/ParakeetTranscriber.swift`
- `Sources/FalaCore/Core/AudioEngine.swift`
- `Sources/FalaCore/Core/AudioConverter.swift`
- `Sources/FalaCore/Core/ModelManager.swift`
- `Sources/FalaCore/Core/MLXModelManager.swift`
- `Sources/FalaCore/UI/SettingsView.swift`
- `Sources/FalaCore/UI/SettingsPanel.swift`
- `Sources/FalaCore/UI/SettingsView+Ext.swift`
- `Sources/FalaCore/UI/SettingsView+LLM.swift`
- `Sources/FalaCore/UI/SettingsView+LLMProviders.swift`
- `Sources/FalaCore/UI/SettingsView+Modes.swift`
- `Sources/FalaCore/UI/TranscribeView.swift`
- `Sources/FalaCore/UI/TranscribeView+Ext.swift`
- `Sources/FalaCore/UI/TranscriptionJob.swift`
- `Sources/FalaCore/UI/TranscriptionJob+Processing.swift`
- `Sources/FalaCore/Modes/DictationMode.swift`
- `Sources/FalaCore/Config/DictationTemplate.swift`
- `Sources/FalaCore/Licensing/LicenseManager.swift`
- `Sources/FalaCore/UI/SettingsView+License.swift`
- `Sources/FalaCore/UI/SettingsView+Updates.swift`
- `Sources/FalaCore/UI/SettingsView+About.swift`

### Referencias externas consultadas

- Apple HIG: [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)
- Apple HIG: [Settings](https://developer.apple.com/design/human-interface-guidelines/settings)
- Apple HIG: [Menus](https://developer.apple.com/design/human-interface-guidelines/menus)
- WhisperKit oficial: [argmaxinc/WhisperKit](https://github.com/argmaxinc/WhisperKit)
- Exemplo oficial de streaming do WhisperKit: [WhisperAX example](https://github.com/argmaxinc/WhisperKit/tree/main/Examples/WhisperAX)
- Implementacao oficial de streaming no WhisperKit: [AudioStreamTranscriber.swift](https://github.com/argmaxinc/WhisperKit/blob/main/Sources/WhisperKit/Core/Audio/AudioStreamTranscriber.swift)
- FluidAudio oficial: [FluidInference/FluidAudio](https://github.com/FluidInference/FluidAudio)

## Achados transversais

Antes de detalhar item por item, alguns problemas estruturais se repetem em varios pontos:

- O app ainda mistura "estado de fundo" com "estado visivel ao usuario". O exemplo mais claro e o warmup: preloading em segundo plano hoje consegue parecer bloqueio ou carregamento real.
- O pipeline de batch e o pipeline de ditado nao compartilham completamente os mesmos recursos aquecidos. Em especial, o Whisper de arquivos continua frio mesmo quando o app ja fez warmup do modelo de ditado.
- A UI de Whisper e a UI de MLX estao em niveis diferentes de maturidade visual e arquitetural. A selecao de MLX ja esta mais proxima de um catalogo nativo; a de Whisper ainda usa uma interface mais antiga.
- Ha pontos importantes em que o erro e engolido em vez de ser convertido em estado de interface. Isso reduz confiabilidade percebida e dificulta diagnostico.
- Algumas decisoes do produto ainda estao acopladas demais a enums fixos e a settings espalhados. Isso trava evolucoes como multiplos modos personalizados e uma organizacao mais coerente das preferencias.

## Itens investigados

### 1. Icone de espera da bandeja e tooltip mentindo sobre carregamento

**Problema observado**

- Em estado teoricamente pronto, o item da barra mostra um simbolo de seta/refresh.
- O tooltip pode dizer que esta carregando o Parakeet mesmo quando isso nao representa um bloqueio real para o usuario.

**Evidencia no codigo**

- `StatusBarController.renderStatusItem()` usa `clock.arrow.circlepath` para `.loading`.
- `AppDelegate.syncWarmupUI` coloca a bandeja em `.loading` sempre que `WarmupCoordinator.isPreparingSelectedResources` for verdadeiro.
- O warmup e disparado no launch, em `didBecomeActive`, depois de salvar settings e depois de download concluido.

**Diagnostico inicial**

- O icone atual representa "preparando em segundo plano", mas visualmente se parece com "atualizando", "recarregando" ou "algo pendente".
- O warmup esta sendo exposto como se fosse um estado operacional primario, quando na pratica deveria ser secundario e nao-bloqueante na maior parte dos casos.
- O tooltip atual descreve a atividade do coordenador, nao necessariamente a realidade percebida pelo usuario.

**Direcao recomendada**

- Separar semanticamente:
  - `ready`
  - `busy-user-blocking`
  - `background-preparing`
  - `downloading`
  - `warning-actionable`
- Manter o icone padrao do app em `ready`.
- Mostrar icone de download apenas para download real.
- Tratar warmup como estado de fundo:
  - opcao 1: nao alterar o icone da bandeja;
  - opcao 2: expor apenas uma linha discreta no menu ao abrir;
  - opcao 3: mostrar tooltip de fundo somente se o prewarm estiver realmente atrasando o proximo uso.
- Rever a copy do tooltip para refletir fato e nao inferencia.

**Validacao futura**

- testes unitarios para mapeamento `WarmupStatus`/downloads -> apresentacao da bandeja;
- teste de regressao para garantir que warmup nao use iconografia de download;
- checklist manual com app ocioso, warmup em background e download real.

### 2. Whisper demora demais na primeira transcricao

**Problema observado**

- O primeiro uso do Whisper continua lento, especialmente em arquivo.

**Evidencia no codigo**

- `WarmupCoordinator.warmTranscriptionEngine()` aquece apenas o `dictationModel` quando o motor ativo e Whisper.
- `TranscriptionJob.executeTranscription()` cria um `Transcriber` novo para batch, com `effectiveModel = overrideModel ?? config.batchModel`.
- `Transcriber.loadIfNeeded()` faz cold load do pipeline `WhisperKit(model: variant)` no primeiro uso da instancia.

**Diagnostico inicial**

- O warmup atual nao cobre o caso mais importante da transcricao de arquivo quando `batchModel != dictationModel`.
- Mesmo quando cobre o modelo, o batch cria outra instancia de `Transcriber`, perdendo boa parte do beneficio do aquecimento anterior.
- Parte da latencia tambem vem do caminho de audio: o ditado grava em arquivo WAV temporario e depois converte tudo para `Float` via `AudioConverter.toFloat16k(from:)`.

**Direcao recomendada**

- Introduzir um pool/coordenador de engines de transcricao com cache por combinacao relevante:
  - engine;
  - modelo;
  - idioma;
  - parametros que realmente invalidam o pipeline.
- Aquecer explicitamente:
  - o modelo ativo de ditado;
  - o modelo ativo de batch quando Whisper estiver selecionado;
  - override recente, se o usuario usar override com frequencia.
- Fazer `TranscriptionJob` pedir uma engine compartilhada, e nao instanciar um `Transcriber` ad hoc.
- Medir separadamente:
  - tempo de conversao de audio;
  - tempo de model init;
  - tempo ate primeira janela de texto;
  - tempo total.

**Validacao futura**

- benchmark com fixture curta e fixture longa;
- regressao de cold start para `dictationModel` e `batchModel`;
- teste de integracao garantindo reuso de pipeline aquecido.

### 3. Whisper parece mais lento no geral; avaliar streaming ou escrita progressiva

**Problema observado**

- Ha percepcao de que o Whisper, alem do cold start, e mais lento no geral.
- Existe interesse em avaliar escrita progressiva ou quase em tempo real.

**Evidencia no codigo**

- No ditado, `DictationMode.stopAndTranscribe()` espera o audio inteiro, converte o arquivo todo e so depois chama `transcribe(samples:)`.
- O caminho de batch com Whisper ja recebe updates progressivos por callback e atualiza a UI durante o processo.
- O app nao usa a infraestrutura de streaming do WhisperKit no caminho de ditado.

**Base externa**

- O WhisperKit oficial ja expoe caminho de streaming/real-time, inclusive no exemplo `WhisperAX` e no `AudioStreamTranscriber`.
- O uso atual do app continua em modo batch para o ditado.

**Diagnostico inicial**

- Existe uma oportunidade real de melhorar a experiencia do Whisper, mas isso nao e um "toggle".
- Streaming de texto final e mais complexo do que streaming de preview porque hipoteses parciais podem mudar ao longo da fala.
- O Parakeet, na integracao atual do app, tambem nao esta sendo usado em fluxo realmente incremental.

**Direcao recomendada**

- Fase 1: instrumentar e reduzir cold path antes de mudar UX.
- Fase 2: adicionar preview progressivo em overlay, sem inserir texto no alvo ate a confirmacao final.
- Fase 3: avaliar modo opcional de insercao incremental apenas se houver estrategia robusta de reconciliacao.
- Manter a proposta de UX clara:
  - preview vivo para Whisper pode fazer sentido;
  - insercao viva em qualquer app precisa muito cuidado para nao "brigar" com o usuario.

**Validacao futura**

- spike tecnico separado para Whisper streaming;
- testes de regressao em ditado curto e longo;
- validacao manual em editores reais para evitar flicker e correcao destrutiva.

### 4. Descricao dos motores e modelos esta tecnica e confusa

**Problema observado**

- A escolha entre Parakeet e Whisper continua tecnica demais.
- O app ainda exige conhecimento demais para escolher rapido.

**Evidencia no codigo**

- O footer de `SettingsView+Ext.swift` descreve o motor mais pela tecnologia do que pelo resultado pratico.
- A lista `knownModels` so traz `label` e `estimatedSize`, sem framing de uso.

**Diagnostico inicial**

- Falta hierarquia de informacao orientada a decisao:
  - "recomendado para quase todo mundo";
  - "melhor para controle e arquivos maiores";
  - "mais rapido";
  - "mais configuravel".

**Direcao recomendada**

- Reescrever a UX de selecao de motor com linguagem de produto:
  - `Parakeet (Recomendado)` -> rapido, simples, ideal para a maioria;
  - `Whisper (Mais controle)` -> mais opcoes de modelo e traducao.
- Para Whisper, exibir um subtitulo por modelo focado em cenario, nao em arquitetura.
- Manter o nome tecnico visivel, mas secundario.

**Validacao futura**

- snapshot/UI tests para copy e badges;
- validacao manual com usuario nao tecnico.

### 5. Whisper com dois modelos ativos esta complexo demais

**Problema observado**

- Hoje existe `Modelo de Ditado` e `Modelo Batch / Arquivo`.
- A interface transmite complexidade desnecessaria.

**Evidencia no codigo**

- `SettingsView+Ext.swift` mostra dois pickers em "Modelos Whisper Ativos".
- `AppConfig` e `AppSettings` mantem `dictationModel` e `batchModel` separadamente.

**Diagnostico inicial**

- Do ponto de vista de produto, a separacao existe, mas a UX nao justifica bem por que o usuario deveria gerenciar isso.
- O custo cognitivo e alto e a warmup strategy fica mais dificil.

**Direcao recomendada**

- Simplificar o produto para "Modelo ativo do Whisper".
- Se a equipe ainda quiser preservar flexibilidade, esconder a separacao atras de um disclosure de nivel avancado.
- Se a simplificacao for aprovada, planejar migracao:
  - novo campo unico em config;
  - mapeamento de legacy settings;
  - remocao de badges `dictation`/`batch` do row atual.

**Validacao futura**

- testes de migracao de config;
- testes de regressao de warmup e readiness;
- QA manual de onboarding e batch.

### 6. Tamanhos estimados dos modelos Whisper estao errados

**Problema observado**

- Exemplo relatado: `large-v3-turbo` aparece como `~800 MB`, mas download real observado e muito maior.

**Evidencia no codigo**

- `knownModels` em `ModelManager.swift` ainda usa `estimatedSize` hardcoded.

**Diagnostico inicial**

- A informacao atual gera desconfiança porque parece precisa, mas nao e.
- Para modelos nao baixados, o numero serve mais como promessa do que como dado.

**Direcao recomendada**

- Curto prazo: remover estimativa quando ela nao for confiavel.
- Medio prazo: alimentar tamanho por manifesto validado, com dado revisado periodicamente.
- Longo prazo: se a origem permitir, mostrar faixa ou tamanho remoto confirmado em vez de numero fixo.

**Validacao futura**

- teste de UI para nao renderizar estimativa enganosa;
- revisao de manifesto ou tabela de metadados com fonte explicita.

### 7. Batch deveria aceitar varios arquivos e montar fila

**Problema observado**

- O fluxo atual permite apenas um arquivo por vez.

**Evidencia no codigo**

- `TranscriptionJob.selectFile()` usa `panel.allowsMultipleSelection = false`.
- `TranscribeView.handleDrop(_:)` pega apenas `items.first`.
- `TranscriptionJob` modela um unico `inputURL`.

**Diagnostico inicial**

- A arquitetura da janela de transcricao ainda e monolitica e centrada em um unico job.
- Isso limita um caso forte de uso, principalmente quando o engine e Parakeet.

**Direcao recomendada**

- Criar uma fila explicita de jobs:
  - `QueuedTranscriptionItem`;
  - `BatchQueueCoordinator`;
  - estados `pending`, `preparing`, `transcribing`, `processing`, `done`, `failed`, `canceled`.
- Permitir:
  - selecao multipla no `NSOpenPanel`;
  - drop de varios arquivos;
  - reorder, retry e reveal por item.
- Comecar com concorrencia `1` por padrao.
- Avaliar concorrencia configuravel mais tarde, principalmente para Parakeet.

**Validacao futura**

- testes de fila, cancelamento e persistencia de output;
- testes de batch misto com e sem pos-processamento;
- QA com 5 a 10 arquivos curtos.

### 8. Tela de modelos MLX nao atualiza em tempo real

**Problema observado**

- O download ou o estado do modelo so aparece atualizado depois de trocar de tela e voltar.

**Evidencia no codigo**

- `SettingsView` observa `settings` e `modelManager`, mas nao observa `mlxModelManager`.
- `SettingsView+LLMProviders.swift` le `settings.mlxModelManager.downloads[...]`, mas a view pai nao recebe invalidacao direta desse child object.

**Diagnostico inicial**

- Este item esta praticamente confirmado como bug de observacao/refresh da UI.

**Direcao recomendada**

- Extrair a area de catalogo MLX para subviews com `@ObservedObject` explicito do `mlxModelManager` e do `mlxCatalogService`.
- Garantir atualizacao em tempo real para:
  - progresso;
  - status de download concluido;
  - erro;
  - tamanho em disco;
  - CTA `Baixar` -> `Selecionar` -> `Remover`.

**Validacao futura**

- teste de view source/integacao para refresh em mudanca de `downloads`;
- QA manual iniciando e concluindo downloads sem navegar para fora da tela.

### 9. Pos-processamento com MLX parece ignorado

**Problema observado**

- O usuario percebe que o MLX nao esta sendo aplicado no pos-processamento de batch.
- Existe alerta visual em algum ponto, mas sem explicacao util.

**Evidencia no codigo**

- `TranscriptionJob+Processing.applyLLM(...)` captura erro, faz `print("[Fala] LLM Error: ...")` e devolve o texto bruto.
- No batch, esse erro nao e traduzido para `state`, `NoticeCard` ou mensagem persistente na janela.

**Diagnostico inicial**

- O comportamento atual falha de forma silenciosa demais.
- Mesmo quando a readiness deixa iniciar, o processamento pode falhar depois e o usuario recebe um resultado que parece "ignorado".

**Direcao recomendada**

- Tornar erro de LLM em batch um estado de produto, nao apenas log:
  - banner explicando que a transcricao saiu sem pos-processamento;
  - opcao de reprocessar texto ja transcrito;
  - detalhes minimos do motivo.
- Separar claramente:
  - erro de configuracao/readiness;
  - erro de inferencia/runtime;
  - fallback deliberado para texto cru.

**Validacao futura**

- testes de integracao cobrindo erro de MLX e fallback explicitado;
- QA manual com modelo ausente, modelo invalido e erro de runtime.

### 10. Download de modelos MLX pode travar e fechar o app ao concluir

**Problema observado**

- Existe relato de fechamento da aplicacao quando o download termina.

**Evidencia no codigo**

- `MLXModelManager.download(...)` so baixa os arquivos e, ao concluir, publica `.mlxDownloadCompleted`.
- `AppDelegate.handleModelDownloadCompleted()` dispara `warmupCoordinator.scheduleSelectedWarmup()`.
- `WarmupCoordinator.warmSelectedLLM()` pode chamar `MLXModelCache.shared.warmup(repoID:)` imediatamente apos o download, o que carrega o modelo na memoria.

**Diagnostico inicial**

- O comentario em `MLXModelManager` tenta evitar OOM durante download, mas o app pode reintroduzir pico de memoria exatamente na conclusao ao aquecer automaticamente o modelo selecionado.
- Este item ainda precisa reproducao instrumentada com crash log e medicao de memoria para confirmacao.

**Direcao recomendada**

- Investigar com prioridade de confiabilidade:
  - crash reports;
  - Allocations;
  - VM Tracker;
  - Time Profiler.
- Adiar o warmup automatico de MLX recem-baixado ate o app estar realmente ocioso.
- Gatear warmup por heuristica de memoria disponivel e classe de hardware.
- Se necessario, trocar warmup completo por validacao leve de integridade no fim do download.

**Validacao futura**

- reproducao com modelo pequeno e medio;
- teste manual com download concluindo em foreground e background;
- telemetria local de tempo/memoria durante pos-download.

### 11. Whisper e MLX usam interfaces de selecao de modelo diferentes

**Problema observado**

- A interface nova de MLX esta melhor do que a de Whisper.
- O produto aparenta duas geracoes de UI convivendo no mesmo fluxo.

**Evidencia no codigo**

- Whisper usa `ModelRow` e pickers legados.
- MLX usa `MLXCatalogSelectionSummaryView` e `MLXCatalogModelRow`.

**Diagnostico inicial**

- A falta de padrao piora a curva de aprendizado e aumenta custo de manutencao.

**Direcao recomendada**

- Definir um componente de catalogo de modelos reutilizavel para motores locais:
  - cabecalho/resumo do selecionado;
  - rows com descricao, tamanho, estado e acao primaria;
  - badges de recomendado/ativo/ideal para este Mac.
- Adaptar Whisper para esse mesmo dialeto visual, respeitando diferencas reais do motor.

**Validacao futura**

- snapshot/UI tests dos dois catalogos;
- auditoria de tokens/componentes para evitar novo hardcode.

### 12. Prompts nao deveriam ser escondidos ou somente leitura

**Problema observado**

- O fluxo atual deixa alguns prompts editaveis e outros somente leitura, principalmente no Apple Intelligence.
- Isso quebra a expectativa de controle total.

**Evidencia no codigo**

- `SettingsView+Modes.swift` usa `appleIntelligencePromptNote` com editor somente leitura.
- O global prompt tambem tem outra interface separada em `SettingsView+LLM.swift`.

**Diagnostico inicial**

- A restricao foi feita por limitacao pratica do provider, nao porque o produto precise esconder a instrucao.
- Mesmo com provider mais fraco, o melhor caminho e expor o prompt com aviso de capacidade e opcao de restaurar o padrao.

**Direcao recomendada**

- Criar um componente unico de edicao de prompt:
  - titulo;
  - editor;
  - ajuda contextual;
  - contador/limite quando aplicavel;
  - restaurar padrao;
  - badge de compatibilidade do provider.
- Permitir edicao tambem no Apple Intelligence, mas com aviso claro:
  - o modelo e compacto;
  - prompts longos/complexos podem degradar o resultado.
- Uniformizar o visual entre:
  - prompt global;
  - prompt por modo;
  - prompt customizado.

**Validacao futura**

- testes de persistencia e restauracao;
- QA manual para Apple, MLX, Gemini e OpenAI.

### 13. Talvez faca sentido unificar Licenca, Atualizacoes e Sobre

**Problema observado**

- O sidebar de Ajustes esta ficando fragmentado.

**Evidencia no codigo**

- `SettingsPanel` ainda mantem `license`, `updates` e `about` como paineis separados.

**Diagnostico inicial**

- Ha sinal de fragmentacao real.
- Em paralelo, opcoes de transcricao de arquivo e de motor estao espalhadas em paineis que nao refletem bem o modelo mental do usuario.

**Direcao recomendada**

- Reestruturar o sidebar para menos categorias e mais coerencia:
  - `Geral`
  - `Motor de Transcricao`
  - `Transcricao de Arquivos`
  - `IA & Prompts`
  - `Aplicacao`
- Em `Aplicacao`, agrupar:
  - licenca/trial;
  - atualizacoes;
  - versao/sobre.
- Seguir HIG: sidebar curta, nomenclatura orientada ao que o usuario quer fazer, nao a implementacao interna.

**Validacao futura**

- testes de navegacao e selecao de painel;
- auditoria de strings/localizacao;
- QA manual de discoverability.

### 14. Mais de um modo personalizado

**Problema observado**

- Um unico modo personalizado parece pouco.

**Evidencia no codigo**

- `DictationTemplate` e um enum fixo com `raw`, `translate`, `custom`, `askAI`.
- `customModeName` e `customModePrompt` sao unicos.

**Diagnostico inicial**

- Este item e valioso, mas nao e ajuste pontual.
- Ele exige remodelar:
  - persistencia;
  - menu da bandeja;
  - sidebar de Ajustes;
  - onboarding e possivelmente readiness.

**Direcao recomendada**

- Evoluir para modelo de dados dinamico:
  - templates built-in continuam fixos;
  - `UserMode` vira colecao persistida;
  - menu rapido e settings passam a renderizar lista de modos do usuario.
- Manter um fluxo claro de criar, duplicar, renomear, ordenar e remover.

**Validacao futura**

- testes de migracao do `custom` atual;
- testes de renderizacao dinamica no menu rapido;
- QA manual com 3 ou mais modos criados.

### 15. Parakeet as vezes fica muito lento no ditado rapido

**Problema observado**

- O fluxo "segurou, falou, soltou, inseriu" precisa ser o caminho mais otimizado do produto, mas ainda apresenta variacao de latencia.

**Evidencia no codigo**

- `DictationMode.stopAndTranscribe()` sempre:
  - finaliza gravacao em arquivo;
  - converte o arquivo inteiro para `Float`;
  - calcula RMS/silencio;
  - so entao chama a engine.
- O caminho grava em disco temporario mesmo quando o destino final e somente o ditado rapido.

**Diagnostico inicial**

- Parte da variacao pode estar antes da inferencia, e nao no Parakeet em si.
- O caminho atual tem IO de arquivo + conversao de audio + inferencia + pos-processamento + insercao.
- Sem instrumentacao, a percepcao de "Parakeet lento" pode estar mascarando custo de pipeline ao redor dele.

**Direcao recomendada**

- Adicionar signposts por etapa:
  - stop recording;
  - conversao;
  - transcricao;
  - pos-processamento;
  - insercao.
- Investigar caminho em memoria para ditado, evitando hop desnecessario por WAV temporario.
- Priorizar o fluxo de ditado como trilha critica do produto.

**Validacao futura**

- benchmark repetido com audio curto;
- mediana e p95 por etapa;
- regressao automatizada de latencia onde for viavel.

### 16. Reorganizacao dos Ajustes por modelo mental do produto

**Problema observado**

- Itens relacionados a transcricao de arquivo estao espalhados entre `Geral`, `Modelos` e `Avancado`.
- "Modelos" na pratica e "Motor de Transcricao".

**Evidencia no codigo**

- `generalView` contem `Armazenamento`, que afeta apenas transcricao de arquivo.
- `advancedView` mistura temperatura Whisper com diarization e substituicao de texto, que sao itens de arquivo/pipeline.
- `modelsView` mistura escolha de engine com gerenciamento de modelos.

**Diagnostico inicial**

- O sidebar atual reflete crescimento incremental do app, nao uma arquitetura de preferencia consolidada.

**Direcao recomendada**

- Proposta de redistribuicao:
  - `Geral`: atalho global, idioma da interface.
  - `Motor de Transcricao`: escolha de engine, idioma do engine, catalogo Whisper/Parakeet.
  - `Transcricao de Arquivos`: armazenamento, diarization, pos-processamento de batch, substituicoes, formato de saida.
  - `IA & Prompts`: provider global, catalogo MLX, credenciais cloud, prompts.
  - `Aplicacao`: licenca, atualizacoes, sobre.
- Renomear `Modelos` para `Motor de Transcricao`.

**Validacao futura**

- testes de navegacao;
- QA de copy e localizacao;
- revisao de onboarding e deep links de readiness.

## Recomendacoes de implementacao por trilha

### Trilha A: Confiabilidade e verdade de estado

- corrigir semantica da bandeja;
- corrigir refresh em tempo real do MLX;
- parar de engolir erro de pos-processamento;
- investigar crash no fim do download MLX.

### Trilha B: Performance de transcricao

- instrumentar ditado e batch;
- reusar engine/modelo aquecido;
- aquecer Whisper batch corretamente;
- depois avaliar streaming do Whisper.

### Trilha C: Simplificacao de UX

- melhorar copy de motores/modelos;
- simplificar Whisper para modelo ativo unico ou modo avancado oculto;
- remover estimativas de tamanho nao confiaveis;
- padronizar catalogos de modelos.

### Trilha D: Informacao arquitetural e customizacao

- unificar editor de prompts;
- permitir edicao de prompt para Apple;
- preparar evolucao para multiplos modos personalizados.

### Trilha E: Arquitetura dos Ajustes

- reestruturar sidebar;
- agrupar itens de transcricao de arquivo;
- consolidar itens de aplicacao.

## Matriz de valor x velocidade para preencher depois

Usar esta tabela na proxima rodada, depois de alinharmos produto e reproducoes:

| Item | Valor | Velocidade | Risco | Observacoes |
| --- | --- | --- | --- | --- |
| Bandeja: estado real vs warmup | TBD | TBD | TBD | Bug de confianca visual |
| MLX: refresh em tempo real | TBD | TBD | TBD | Bug confirmado de observacao |
| Batch: erro de MLX explicito | TBD | TBD | TBD | Bug confirmado de fallback silencioso |
| MLX: crash ao concluir download | TBD | TBD | TBD | Precisa reproducao com Instruments |
| Whisper: cold start em arquivo | TBD | TBD | TBD | Gap claro entre warmup e batch |
| Ditado rapido: variacao de latencia | TBD | TBD | TBD | Precisa telemetria local |
| Streaming Whisper / preview vivo | TBD | TBD | TBD | Mudanca de UX + arquitetura |
| Simplificacao do Whisper para modelo unico | TBD | TBD | TBD | UX forte, impacto em config |
| Fila de varios arquivos | TBD | TBD | TBD | Alto valor de uso |
| Padronizacao da UI de catalogo | TBD | TBD | TBD | UX e manutencao |
| Editor unico de prompts | TBD | TBD | TBD | Reuso de componente |
| Multiplos modos personalizados | TBD | TBD | TBD | Trabalho estrutural |
| Reorganizacao dos Ajustes | TBD | TBD | TBD | Impacta discoverability |

## Observacoes finais

- A automacao de validacao de licenca ja esta mais madura do que a percepcao inicial sugeria. O `LicenseManager` atual ja tenta bootstrap do trial e retries automáticos; o problema aqui e mais de feedback e organizacao da interface do que ausencia completa de logica.
- O item "Whisper em tempo real" deve ser tratado como uma investigacao de produto e arquitetura, nao como ajuste fino. A base externa permite isso, mas a experiencia final precisa proteger o usuario de texto instavel.
- O item "mais de um modo personalizado" tambem precisa ser tratado como epico, nao como ajuste de tela.
