# PLANO — Fala

> Documento canônico de especificação operacional e acompanhamento do projeto.

## Propósito deste arquivo
- Este arquivo define o que o produto está construindo e acompanha o progresso por meio de checkboxes.
- Este arquivo registra apenas decisões fechadas, escopo aprovado, trabalho em andamento, backlog validado e itens concluídos.
- Este arquivo não contém snippets de código, explicações de implementação, changelog, commits, releases ou relato histórico.
- Mudanças de escopo devem entrar primeiro na definição do item correspondente; o checklist serve apenas para acompanhamento.

## Decisões fechadas
- O `PLANO.md` é a fonte única de verdade do plano do projeto.
- O `Meeting Mode` entra como iniciativa principal nova do produto.
- O escopo inicial de `Meeting Mode` é sessão completa: captura ao vivo, transcript em tempo real, histórico de sessão e notas pós-reunião.
- O `Meeting Mode` não inclui copiloto em tempo real nem sugestões contextuais durante a chamada no primeiro release.
- A persistência de reuniões é `opt-in`; por padrão, a reunião pode funcionar sem salvar automaticamente no disco.
- O histórico textual do produto é `opt-in`.
- Métricas e estatísticas ficam locais no dispositivo.
- O produto não terá telemetria remota como parte deste roadmap.
- A captura de áudio do sistema para reuniões fica disponível apenas em macOS `14.2+`.
- Em macOS abaixo de `14.2`, o `Meeting Mode` funciona apenas com microfone.
- `Command Mode` não faz parte deste roadmap atual.
- Busca em base de conhecimento e sugestões durante reunião ficam fora do escopo imediato.

## Roadmap ativo

### Meeting Mode
Status: Planned

Definição:
- Modo dedicado para gravar e transcrever reuniões ao vivo dentro do Fala.
- O transcript deve identificar a origem do áudio entre microfone e áudio do sistema.
- O usuário deve conseguir acompanhar a sessão em tempo real sem sair do aplicativo.

Inclui:
- Captura contínua de microfone.
- Captura contínua de áudio do sistema quando suportada.
- Transcript ao vivo com estado de sessão.
- Controles de iniciar, parar, copiar e exportar.
- Seleção de dispositivo de entrada para o microfone.

Não inclui:
- Sugestões durante a reunião.
- Diarização por múltiplos participantes reais.
- Automação de comandos do sistema.

Checklist:
- [ ] Configuração persistente do modo reunião.
- [ ] Captura contínua de microfone para reunião.
- [ ] Captura contínua de áudio do sistema com gate de versão.
- [ ] Segmentação de fala e transcrição contínua.
- [ ] Transcript ao vivo com origem do áudio.
- [ ] Controles de iniciar, parar, copiar e exportar.
- [ ] Fallback explícito para `mic-only` quando não houver captura de sistema.
- [ ] Aviso de consentimento antes da primeira gravação.

### Sessão e notas
Status: Planned

Definição:
- Cada reunião deve existir como sessão operável no app.
- Sessões podem ser efêmeras ou persistidas, conforme configuração do usuário.
- Após o encerramento, o usuário pode gerar notas estruturadas a partir da sessão.

Inclui:
- Persistência opt-in de sessões.
- Sessões efêmeras com cópia e exportação manual.
- Histórico de sessões.
- Geração de notas pós-reunião.
- Templates de notas.

Não inclui:
- Edição colaborativa.
- Sincronização em nuvem.
- Sugestões em tempo real a partir das notas.

Checklist:
- [ ] Store de sessões com transcript estruturado.
- [ ] Sessão efêmera sem persistência automática.
- [ ] Encerramento drenado da sessão sem perder o final do transcript.
- [ ] Lista de sessões com reabertura, busca e exclusão.
- [ ] Exportação de transcript da sessão.
- [ ] Templates de notas pós-reunião.
- [ ] Geração de notas a partir de sessão encerrada.
- [ ] Exportação de notas.

### Activity Center e stats
Status: Planned

Definição:
- O produto deve ter um centro local de atividade para unificar ditado, batch e reuniões.
- As estatísticas devem ser derivadas da atividade local do usuário.
- O foco é dar visibilidade de uso sem enviar dados para fora.

Inclui:
- Histórico unificado de uso.
- Busca e limpeza da atividade.
- Estatísticas locais derivadas da atividade.
- Tempo economizado, volume de uso e recorrência.

Não inclui:
- Telemetria remota.
- Dashboard web.
- Coleta de dados pessoais fora do dispositivo.

Checklist:
- [ ] Store unificado de atividade.
- [ ] Histórico textual opt-in.
- [ ] Busca, cópia e exclusão de itens de atividade.
- [ ] Estatísticas locais derivadas da atividade.
- [ ] Tempo economizado.
- [ ] Indicadores de uso recorrente.
- [ ] Controles claros de privacidade para histórico e stats.

### Onboarding
Status: Active

Definição:
- O onboarding deve levar o usuário até o primeiro sucesso real no produto.
- O fluxo deve confirmar permissões, prontidão técnica e teste funcional.
- O objetivo é reduzir atrito antes do primeiro uso completo.

Inclui:
- Checklist de prontidão.
- Permissões e validações principais.
- Teste guiado dentro do app.
- Orientação de configuração inicial.

Não inclui:
- Tutorial longo por feature.
- Conteúdo de suporte avançado.
- Histórico detalhado de mudanças do produto.

Checklist:
- [x] Janela de onboarding dedicada.
- [x] Checklist de microfone, acessibilidade, licença, motor e IA.
- [ ] Sandbox de teste guiado no onboarding.
- [ ] Configuração de hotkey dentro do onboarding.
- [ ] Primeiro uso validado por teste bem-sucedido.
- [ ] Inclusão do `Meeting Mode` no fluxo inicial.
- [ ] Revisão do conteúdo e da navegação para reduzir atrito.

### Edit Mode
Status: Active

Definição:
- O produto deve ter um modo explícito para editar texto com IA.
- O modo precisa funcionar tanto sobre texto selecionado quanto sem seleção.
- O resultado pode ser refinado em sequência sem virar um chat genérico.

Inclui:
- Reescrita sobre seleção.
- Escrita a partir de instrução sem seleção.
- Refinamento rápido sobre o último resultado.
- Resultado com preview ou colagem direta.

Não inclui:
- `Command Mode`.
- Conversa aberta estilo chatbot.
- Sugestões baseadas em conhecimento externo.

Checklist:
- [x] Comando por voz sobre texto selecionado.
- [x] Comando digitado sobre texto selecionado.
- [x] Preview do resultado com opção de colar direto.
- [x] Refinamento rápido sobre o último resultado.
- [ ] Transformar o fluxo atual em modo explícito de edição.
- [ ] Atalho dedicado para o modo de edição.
- [ ] Fluxo sem seleção para escrita do zero.
- [ ] Entrada persistente de follow-up dentro do modo.
- [ ] Superfície própria de UI e configuração para `Edit Mode`.

### Vocabulário do Parakeet
Status: Active

Definição:
- O Fala deve aprender correções do usuário e usar isso para melhorar o resultado futuro.
- O vocabulário precisa unificar regras manuais, correções aprendidas e boosting do Parakeet.
- O fluxo deve ser útil sem bloquear a transcrição normal quando algo falhar.

Inclui:
- Aprendizado de correções após inserção.
- Regras de substituição persistidas.
- Vocabulário específico do Parakeet.
- Fallback seguro quando boosting falhar.

Não inclui:
- Diarização.
- Personalização por usuário em nuvem.
- Ajustes automáticos baseados em telemetria.

Checklist:
- [x] Detectar edição manual logo após inserir texto.
- [x] Comparar texto inserido com texto corrigido.
- [x] Perguntar ao usuário se a correção deve ser aprendida.
- [x] Salvar correção confirmada como regra.
- [x] Descartar correção quando o usuário ignora.
- [x] Cobertura básica por testes unitários para detecção de correção.
- [ ] Gerenciamento unificado de vocabulário e regras no produto.
- [ ] Store dedicado de vocabulário do Parakeet.
- [ ] Termos de boosting específicos do Parakeet.
- [ ] Aplicação de boosting no passe final da transcrição.
- [ ] Unificação entre regras manuais, correções aprendidas e boosting.
- [ ] Fallback seguro quando boosting falhar.

## Backlog validado

### Screenshot + AI Command
Status: Later

Definição:
- Capturar uma área da tela e usar a imagem como contexto de um comando de IA.
- O fluxo deve aceitar comando por voz ou digitado após a captura.

Checklist:
- [ ] Captura interativa de screenshot sem seleção de texto.
- [ ] Preview da imagem no painel flutuante.
- [ ] Pergunta sobre a imagem por voz ou texto.
- [ ] Envio de imagem para modelos com visão.
- [ ] Fallback claro quando o modelo atual não suportar visão.

### Apple Speech / SpeechAnalyzer
Status: Later

Definição:
- Avaliar backends nativos da Apple como opção adicional de transcrição.
- A decisão só entra quando houver ganho claro de qualidade, latência ou compatibilidade.

Checklist:
- [ ] Avaliação técnica do backend legado da Apple.
- [ ] Avaliação técnica do SpeechAnalyzer.
- [ ] Critério objetivo de adoção como backend opcional.

### KB suggestions durante reunião
Status: Later

Definição:
- Usar uma base de conhecimento local para sugerir contexto durante a conversa.
- Esse fluxo só entra depois do `Meeting Mode` e das notas pós-reunião estarem estáveis.

Checklist:
- [ ] Definição da fonte de conhecimento suportada.
- [ ] Estratégia local de indexação e busca.
- [ ] Critério de surfacing de sugestões durante reunião.
- [ ] UI própria para sugestões sem poluir o transcript.

## Concluído

### Selection + AI Command
Status: Done

Definição:
- Aplicar comandos de IA sobre texto selecionado por voz ou por input digitado.

Checklist:
- [x] Captura de seleção no início do fluxo.
- [x] Fluxo por voz sobre seleção.
- [x] Fluxo digitado sobre seleção.
- [x] Preview ou substituição direta do resultado.
- [x] HUD dedicado para o modo de seleção.

### QuickEdit pós-resultado
Status: Done

Definição:
- Permitir refinamento rápido sobre o resultado recém-gerado sem reiniciar o fluxo.

Checklist:
- [x] Painel temporário após resultado.
- [x] Refinamento encadeado sobre o último resultado.
- [x] Compatibilidade com preview e colagem direta.

## Regras de manutenção
- Alteração de escopo entra primeiro na seção `Definição`.
- Checkbox serve apenas para entregar algo verificável no produto ou na arquitetura.
- Não registrar commits, releases ou detalhes de implementação neste arquivo.
- Não criar subtarefas excessivamente pequenas.
- Ao concluir algo, apenas marcar `[x]`.
- Se uma iniciativa sair de prioridade, mover o `Status` para `Paused`, `Blocked` ou `Later`.
