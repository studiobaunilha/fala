# Changelog

Todas as mudanças notáveis do Fala serão documentadas aqui.

## [Em preparação]

### Melhorias

- **Whisper com seleção simplificada**: O app converge para um único modelo Whisper ativo, com catálogo e ações mais diretas para transcrição.
- **Catálogo de transcrição padronizado**: A escolha de modelos de transcrição passa a usar a mesma linguagem visual e os mesmos componentes reutilizáveis do restante do app.
- **Ajustes reorganizados**: O painel de Ajustes passa a refletir melhor o modelo mental do produto, separando motor de transcrição, transcrição de arquivos, IA/LLM e configurações da aplicação.
- **Editor único de prompts**: Prompts relevantes passam a usar a mesma interface de edição, e o prompt do Apple Intelligence deixa de ser somente leitura.
- **Fila de vários arquivos**: A transcrição de arquivos ganha seleção múltipla, fila visível, progresso por item, retentativa e atalho para abrir saídas no Finder.

### Correções

- **Diarization removida do produto**: O app deixa de expor diarization em Ajustes, transcrição de arquivos, prompts e configuração persistida, eliminando estados residuais do recurso.
- **Prompt global ocultado com Apple Intelligence**: O painel `IA & LLM` deixa de mostrar o prompt global quando o provedor padrão selecionado é Apple Intelligence, evitando uma configuração sem efeito.
- **Layout dos Ajustes corrigido**: A janela de Ajustes volta a respeitar a área útil inteira, sem clipping no conteúdo da direita e sem o painel lateral extrapolar o contêiner.
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
