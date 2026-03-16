# Changelog

Todas as mudanças notáveis do Fala serão documentadas aqui.

## [1.11.2] — 2026-03-16

### Melhorias
- **Painel de refinamento desativado no fluxo de colagem (QuickEdit)**: Atendendo a feedbacks de que o painel de ajuste interrompia a digitação fluida após a colagem de resultados de IA, a janela automática de 5 segundos foi desabilitada. A funcionalidade permanece arquiteturada para o futuro, mas inativa por padrão nesta versão.

---

## [1.11.1] — 2026-03-16

### Correções
- **Timer de refinamento ajustado**: O timer de fechamento de 5 segundos agora só se aplica quando o texto é colado diretamente na sua tela. Quando a opção "Colar resultado direto" está desligada e o app exibe a janela de preview, ela ficará aberta por tempo indeterminado até você fechar ou aprovar.

---

## [1.11] — 2026-03-16

### Funcionalidades
- **QuickEdit pós-resultado**: Após inserir um texto via ditado ou IA, um pequeno painel flutuante apresenta a pergunta "Quer ajustar?" por 5 segundos. Isso permite enviar um comando de refinamento rápido (ex: "mais formal", "traduz pra inglês") que substitui o texto original, criando um fluxo conversacional fluido sem sair do contexto.

---

## [1.10] — 2026-03-16

### Funcionalidades
- **Seleção + Comando de IA**: Agora você pode selecionar um texto em qualquer app e usar o atalho do Fala para modificá-lo. Pressione e segure o atalho para falar a instrução (ex: "Traduza isso para inglês") ou dê um toque curto para abrir um painel flutuante e digitar o comando. A IA vai usar o seu texto selecionado como contexto e colar o resultado por cima dele.
- **Redesign do HUD de Ditado**: O clássico painel quadrado de gravação foi substituído por uma elegante "pílula" compacta que exibe waveforms coloridas e animadas, reagindo à sua voz em tempo real e usando materiais nativos do sistema.
- **Preview de Resultados**: Uma nova configuração em *Ajustes > Geral > Comportamento de IA* permite desligar o "Colar resultado direto". Quando desligado, a IA exibe o texto gerado num painel flutuante para você revisar antes de decidir se quer colar (Cmd+Enter) ou descartar (Esc).

## [1.3] — 2026-03-10

### Funcionalidades

- **Perguntar à IA com contexto de seleção**: Ao ativar o modo "Perguntar à IA", o Fala captura automaticamente o texto selecionado no app em foco e o inclui como contexto na pergunta enviada à IA.
- **Memória de conversação no askAI**: O modo "Perguntar à IA" agora mantém histórico de turnos, permitindo perguntas de acompanhamento como "e sobre X?". A memória reseta automaticamente após 5 minutos de inatividade ou ao trocar de template/provedor.
- **Badge de turnos no painel flutuante**: O painel de feedback de ditado exibe um indicador com o número de turnos ativos na conversação.

### Melhorias

- **Prompts otimizados por provedor**: Cada provedor de IA (Gemini, OpenAI, Apple Intelligence, MLX) recebe um prompt padrão otimizado para suas características — prompts completos em português para provedores cloud, e prompts concisos em inglês para modelos locais de contexto curto.
- **Eliminação do prompt global**: O campo "Prompt Global do Sistema" foi removido dos Ajustes. Cada modo agora gerencia seu prompt de forma independente, simplificando a configuração.
- **Strip de tags de pensamento**: Respostas de modelos como Qwen3 e DeepSeek R1 são automaticamente limpas de tags `<think>...</think>` antes de serem inseridas.
- **Telemetria de batch com tamanho e duração**: Os logs de transcrição de arquivos agora incluem o tamanho do arquivo de entrada e a duração do áudio, facilitando a análise de performance.
- **Etapa de salvamento medida separadamente**: A telemetria de batch agora separa o tempo de escrita do arquivo de saída (`save=`) das demais etapas.
- **Logs de batch sempre ativos**: A telemetria de transcrição de arquivos agora é sempre emitida, tanto na UI quanto no CLI, sem necessidade da flag `--profile`.
- **Logs de batch via os.Logger**: A telemetria de batch migrou de `NSLog` para `os.Logger` com subsystem/category, garantindo persistência nos logs do sistema.

### Correções

- **Formulário de ativação ocultado quando Pro ativo**: A seção de ativação de licença não aparece mais nos Ajustes quando o Fala Pro já está ativado.
- **Apple Intelligence excluído de multi-turn**: O Apple Intelligence (~3B on-device) agora trata cada chamada como independente, evitando degradação de qualidade com histórico de conversação.

---

## [1.2.1] — 2026-03-09

### Correções

- **Ativação direta no Onboarding**: O fluxo de boas-vindas agora permite ativar chaves Pro ou iniciar o trial sem precisar abrir a janela de Ajustes.
- **Keychain sem erro -50**: Corrigida uma falha de comunicação com o sistema de segurança do macOS que impedia o carregamento de licenças em certos ambientes.
- **Feedback de validação no startup**: O app agora mostra um indicador visual de progresso enquanto tenta revalidar a licença automaticamente em segundo plano.
- **Refatoração interna do Onboarding**: O código da interface de setup foi modularizado para maior estabilidade e conformidade com os padrões de qualidade do projeto.

---

## [1.2] — 2026-03-09

### Melhorias

- **Whisper com seleção simplificada**: O app converge para um único modelo Whisper ativo, com catálogo e ações mais diretas para transcrição.
- **Catálogo de transcrição padronizado**: A escolha de modelos de transcrição passa a usar a mesma linguagem visual e os mesmos componentes reutilizáveis do restante do app.
- **Ajustes reorganizados**: O painel de Ajustes passa a refletir melhor o modelo mental do produto, separando motor de transcrição, transcrição de arquivos, IA/LLM e configurações da aplicação.
- **Editor único de prompts**: Prompts relevantes passam a usar a mesma interface de edição, e o prompt do Apple Intelligence deixa de ser somente leitura.
- **Fila de vários arquivos**: A transcrição de arquivos ganha seleção múltipla, fila visível, progresso por item, retentativa e atalho para abrir saídas no Finder.
- **Telemetria de batch**: Cada execução de transcrição de arquivos passa a registrar tempos de preparo de áudio, preparo do motor, transcrição, pós-processamento e total.
- **Diagnóstico de batch mais preciso**: A telemetria de transcrição de arquivos passa a diferenciar fast path `WAV` vs conversão real e também marca se o modelo estava `ready`, `loading` ou `cold`.
- **CLI de batch com profiling**: O comando `fala transcribe` passa a aceitar `--profile` e imprime o breakdown de preparo de áudio, warmup do modelo e transcrição para comparação reproduzível fora da UI.
- **CLI de batch com preparo isolado**: O comando `fala transcribe` passa a aceitar `--prepare-only`, permitindo medir só a normalização de áudio antes do warmup e da transcrição.
- **Regressão E2E de AAC validada pela stack da Apple**: A cobertura de batch passa a gerar um `m4a` pela própria stack nativa da Apple para validar o executável construído com `--prepare-only` sem depender de fixtures sintéticos pouco representativos.

### Correções

- **Licença preservada com Keychain bloqueado**: Erros de acesso ao Keychain no startup passaram a ser tratados como transientes, evitando a remoção acidental do token Pro da máquina.
- **Onboarding com ativação manual**: O setup inicial agora permite abrir os Ajustes para colar chaves de ativação manualmente caso a validação automática não seja possível.
- **Transcrição Parakeet sem travamento da UI**: A inicialização pesada do motor CoreML (prewarm) passou a rodar em thread isolada, garantindo que a interface não congele ao iniciar o ditado.
- **Diarization removida do produto**: O app deixa de expor diarization em Ajustes, transcrição de arquivos, prompts e configuração persistida, eliminando estados residuais do recurso.
- **Prompt global ocultado com Apple Intelligence**: O painel `IA & LLM` deixa de mostrar o prompt global quando o provedor padrão selecionado é Apple Intelligence, evitando uma configuração sem efeito.
- **Layout dos Ajustes corrigido**: A janela de Ajustes volta a respeitar a área útil inteira, sem clipping no conteúdo da direita e sem o painel lateral extrapolar o contêiner.
- **Chrome nativo dos Ajustes restaurado**: A janela de Ajustes volta a usar o comportamento nativo de sidebar full-height do macOS, com traffic lights e toggle da barra lateral alinhados ao padrão Apple.
- **Licença revalidada automaticamente no launch**: Quando o app sobe bloqueado por licença ou trial, o startup passa a tentar a reconciliação online em background antes de depender de clique manual na janela de pendências.
- **CLI de batch destravado**: O entrypoint do executável deixa de bloquear trabalho async com semáforo e passa a executar o fluxo de transcrição de arquivos corretamente.
- **Batch com estágios e cancelamento honestos**: A UI de transcrição de arquivos passa a distinguir preparo do motor, transcrição e cancelamento, e o pipeline interrompe mais cedo quando o usuário cancela.
- **Preparo de áudio do batch deixa de bloquear a UI**: A conversão inicial passa a rodar fora do `MainActor`, o cancelamento interrompe o pipeline antes do warmup/transcribe e arquivos temporários parciais são limpos ao abortar.
- **Batch sem dependência externa de `ffmpeg`**: A preparação de áudio para transcrição de arquivos passa a ser nativa, evitando depender de Homebrew em máquinas limpas.
- **Empacotamento mais confiável**: O pipeline de build e release valida o conteúdo staged do `.app` antes de empacotar, reduzindo risco de bundle incompleto na distribuição.

---

## [1.1] — 2026-03-08

### Funcionalidades

- **Onboarding guiado por readiness**: O app passa a orientar a configuração inicial a partir do estado real do runtime, evitando uso com dependências incompletas.
- **Catálogo MLX curado por manifesto**: Modelos locais de MLX passam a ser definidos por um catálogo validado pelo app, em vez de um fluxo aberto e menos previsível.
- **Licenciamento com entitlement tokens**: O fluxo PRO deixa de depender do modelo antigo e passa a usar tokens de entitlement, com trial e ativação mais robustos.

### Melhorias

- **Warmup e preload do runtime**: O app passa a aquecer recursos de transcrição com mais segurança, reduzindo cold start e melhorando previsibilidade.
- **Localização recomposta a partir do catálogo**: A interface, especialmente em Ajustes, passa a consumir melhor os recursos localizados compilados.
- **Toolchain e builds normalizados**: O fluxo de desenvolvimento e validação passa a resolver a toolchain do Xcode dinamicamente e a verificar bundles empacotados durante o build.

### Correções

- **Modelos MLX incompletos deixam de parecer válidos**: O app passa a exigir pesos completos em disco antes de considerar um modelo utilizável.
- **Bandeja e progresso de download estabilizados**: Tooltip, ícones e progresso na barra de menu passam a refletir o estado real sem comportamento inconsistente.
- **Restauração de licença via Keychain endurecida**: Leituras de licença passam a ser consolidadas em lote, reduzindo inconsistências e prompts redundantes.
- **Reinício confiável após mudanças críticas**: O app passa a reabrir de forma verificável quando uma configuração exige restart, com fallback honesto quando necessário.

---

## [1.0.2] — 2026-03-05

### Correções

- **Diarization incompatível com Apple Intelligence ficou explícita**: Em vez de deixar o comportamento ambíguo, o app agora bloqueia o recurso e mostra feedback coerente na interface.
- **Pipeline de release corrigido**: O script de publicação deixa de falhar por causa de um caractere invisível que quebrava a execução do shell.

---

## [1.0.1] — 2026-03-05

### Correções

- **Transcrição de arquivo respeita o motor ativo**: A transcrição de arquivos deixa de ignorar a seleção de Parakeet e passa a usar o motor configurado corretamente.
- **Apple Intelligence responde no idioma configurado**: O modo "Perguntar à IA" passa a enviar instrução explícita de idioma para evitar respostas em idioma incorreto.
- **Diarization sincronizada entre telas**: O toggle de diarization deixa de divergir entre Ajustes e a tela de transcrição de arquivos.
- **Modo personalizado com incompatibilidade explícita**: Quando Apple Intelligence não suporta o fluxo, o app passa a exibir aviso em vez de esconder o modo.

### Melhorias

- **Picker de modelo adaptado ao motor**: O seletor de modelo passa a refletir corretamente o motor ativo e simplifica a UI quando o motor não possui variantes.
- **Labels de padrão mais informativas**: Opções que usam o padrão dos Ajustes passam a mostrar o valor ativo entre parênteses.
- **Feedback de diarization mais claro**: A interface explica com mais precisão que a diarization depende de pós-processamento com IA e não de detecção acústica.
- **Avisos de incompatibilidade mais consistentes**: Sidebar, detalhes do modo e menu bar passam a comunicar restrições do Apple Intelligence de forma uniforme.

---

## [1.0] — Lançamento Inicial

### Funcionalidades

- Ditado por voz com push-to-talk via atalho global
- Motores de transcrição: Whisper (WhisperKit) e Parakeet V3 (FluidAudio/CoreML)
- Provedores de IA: Apple Intelligence, Gemini, OpenAI, MLX local
- Modos de ditado: Transcrição, Tradução para Inglês, Perguntar à IA, Personalizado
- Transcrição de arquivos de áudio (batch)
- Diarization via pós-processamento com IA
- Substituição de texto (find & replace) com múltiplas variantes
- Licenciamento PRO com trial de 7 dias
- Atualizações automáticas via Sparkle + Cloudflare R2
- Pipeline de release automatizado (`scripts/release.sh`)
- Suporte a 25+ idiomas (Parakeet) e 99+ idiomas (Whisper)
- Janela flutuante com feedback visual durante ditado
- Menu bar com atalhos para todos os modos
