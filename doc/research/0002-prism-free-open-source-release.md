# PRISM-0002: Verificar a publicação gratuita e aberta do Fala

**Status:** draft
**Decision ref:** docs/brainstorming/fala-open-source-plan.md

## Decision

Liberar a publicação do Fala gratuito e do código aberto somente quando o pacote, fonte, site e migração de instalações antigas passarem pelos critérios abaixo. Este é o desenho da avaliação; não contém resultados do candidato ainda inexistente.

## Objective

Uma pessoa com Mac compatível consegue baixar, instalar e usar o Fala sem compra, ativação ou prazo, e acessar o fonte correspondente. Quem usa versão antiga tem caminho de atualização verificável. Assinatura e privacidade permanecem protegidas.

## Evaluation question

O mesmo candidato de release oferece esse percurso completo sem depender do servidor de licenças e sem expor material privado?

## Claim

Após execução aprovada, é possível afirmar que a versão identificada foi verificada nos cenários e condições registrados. Não afirmar ausência absoluta de falhas, segurança absoluta ou compatibilidade com todos os Macs.

## Evidence

Testes exercitam decisões de disponibilidade; execução do aplicativo empacotado verifica integração com macOS; servidor Worker com assets reais verifica o site; download público e hash verificam o artefato distribuído; revisão de código, histórico e metadados sustenta a exposição do fonte. Cada evidência é vinculada ao SHA do aplicativo, SHA do site e SHA-256 do pacote. Evidências de outra base ou de um pacote recompilado não são intercambiáveis.

## Tasks

1. Registrar gates de base e candidato: SwiftLint estrito, testes do projeto, localização, build empacotado; ESLint, testes Worker e build Astro.
2. Exercitar primeira abertura sem estado de licença e migração de instalação com estado ausente ou expirado. Não apagar o Keychain real para fabricar cenário: usar ambiente isolado controlado.
3. Com modelos instalados, executar ditado e transcrição de arquivo de fixture já aprovada; usar entrada de teste sem conteúdo privado. Confirmar saída não vazia e utilizável para a tarefa e nenhuma tentativa de ativação/renovação. Testar também falhas esperadas de permissão e modelo ausente para impedir liberação indevida.
4. Usar comandos sobre texto selecionado no aplicativo empacotado. Conferir configuração inicial, ajustes, transcrição e suporte sem ações comerciais.
5. Iniciar Worker local com o build Astro real. Conferir as 13 localidades listadas em `src/i18n/locales.ts`, compra/sucesso antigos, download estável, URLs com barra final e acesso direto a arquivos HTML antigos. Nenhum cenário pode abrir checkout ou carregar scripts Paddle. A lista exata vem do checkout candidato.
6. Conferir assinatura do .app, notarização do DMG, assinatura Sparkle e atualizador a partir de versão antiga. Registrar o caminho manual de atualização também.
7. Executar scan e revisão do conjunto que será público, incluindo branch, tags, histórico, conteúdo e metadados GitHub. Revisar avisos e termos dos componentes; conferir licença escolhida e titularidade.
8. Após o gate final de publicação, baixar o artefato público, comparar seu SHA-256, verificar fonte/tag, repositório público, estado real das vendas e páginas servidas. Só então tratar disponibilidade pública como observada.

Unidade de verificação: cenário identificado por versão do pacote e estado inicial. Repetições do mesmo cenário são rechecagens, sem interpretação estatística. Não há amostragem populacional ou alegação de superioridade.

## Measures

- Resultado pass/fail por cenário e por gate obrigatório.
- Tentativas de endpoints de licença: zero nos percursos novos observados; combinar inspeção dos caminhos de rede e observação em execução, sem confundir ausência no log com prova absoluta.
- Conteúdo comercial ativo: nenhum controle de compra/trial nos assets e páginas servidos; referências históricas devidamente identificadas não são falsos positivos a apagar.
- Hash e versão do download público: igualdade exata com o candidato aprovado.
- Achados de exposição: todos triados, sem segredo ou material privado confirmado pendente no conjunto a publicar.

## Data sources

Testes em `Tests/FalaTests`, fixtures existentes, comandos Makefile e scripts de bundle; testes `worker/test`, lista de localidades e HTMLs Astro do site. Rede e interface são observadas no pacote candidato. Artefatos públicos: repositório, tag, DMG, appcast e site. O levantamento retornou HTTP 403 ao tentar acessar site, download e appcast deste ambiente; essa lacuna precisa ser resolvida antes da verificação pública. Dados de compradores não integram fixtures nem relatórios públicos.

## Decision rule

Escolha de engenharia, definida antes das execuções do candidato: prosseguir somente com todos os gates e cenários obrigatórios aprovados, nenhuma pendência material de revisão ou exposição, e decisão de licença/plano registrada. Falha requer correção e reexecução apenas do que mudou ou foi invalidado. Evidência inacessível ou cenário não executado permanece UNVERIFIED e bloqueia a alegação correspondente de prontidão. Não promover falha preexistente a sucesso; tratar separadamente e resolver o gate aplicável à publicação.

Antes da publicação, só afirmar prontidão local após o percurso montado. Depois da publicação, falha de hash, download, atualização, fonte ou checkout exige parar o anúncio/retirada do backend e corrigir o passo afetado. Não resolver por reativação automática de cobrança nem republicação de segredos ou código comercial.

## Limits

Não mede qualidade comparativa, ganho de adoção, desempenho em toda a linha Apple Silicon, auditoria legal completa ou ausência de toda vulnerabilidade. Provedores remotos de IA continuam opcionais e podem cobrar pelo uso; não fazem parte da promessa de gratuidade do aplicativo. Fontes e modelos de terceiros mantêm seus próprios termos. A inspeção automatizada de segredos tem falsos negativos e não substitui revisão de conteúdo.

## Sources

### M1 — Garantia proporcional e adequação ao uso
- Source: https://www.gov.uk/guidance/the-aqua-book (accessed 2026-11-09 via web).
- Supports: separar execução correta das verificações da adequação do percurso real ao objetivo de publicação.
- Contribution: orienta garantia proporcional ao risco e clareza de limites.
- Adaptation: gates determinísticos de pacote, site e exposição mais cenários reais de instalação/atualização; sem experimento estatístico.
- Retained limit: não fornece requisitos específicos do Fala, números de aceitação ou prova de segurança.

### M2 — Integridade de atualização
- Source: https://sparkle-project.org/documentation/ (accessed 2026-11-09 via web).
- Supports: conferir assinatura do arquivo distribuído e percurso real de atualização.
- Contribution: define os mecanismos de autenticidade do update que precisam continuar operantes.
- Adaptation: verificar DMG e appcast do mesmo candidato, preservando as chaves de atualização.
- Retained limit: assinatura não prova funcionalidade do aplicativo nem remove a necessidade de testar a migração.

### M3 — Roteamento do servidor montado
- Source: https://developers.cloudflare.com/workers/static-assets/routing/worker-script/ (accessed 2026-11-09 via web).
- Supports: verificar páginas estáticas de checkout além da função fetch isolada.
- Contribution: explicita a precedência entre assets e Worker e configuração run_worker_first.
- Adaptation: testar build Astro com Worker e caminhos antigos, removendo os assets comerciais.
- Retained limit: documentação corrente não comprova qual configuração está implantada em produção.
