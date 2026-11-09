# Fala gratuito e open source: proposta, desenho e plano

O resultado solicitado é permitir baixar, usar, estudar e modificar o Fala gratuitamente. Isso exige retirar a ativação comercial do aplicativo, encerrar novas compras no site e publicar o código sob uma licença explícita. A publicação só pode dizer que a mudança está disponível quando código, pacote e página estiverem acessíveis e coerentes.

**Estado:** plano aprovado; implementação autorizada pelo proprietário em 2026-11-09.
**Evidence ref:** `doc/research/0001-ground-free-open-source.md`.
**Evaluation ref:** `doc/research/0002-prism-free-open-source-release.md`.

## Proposta

Abrir `studiobaunilha/fala` e distribuir o DMG gratuito, preservando assinatura Apple e atualizações Sparkle. O site do estúdio continua em repositório privado: abrir o código do Fala não exige abrir os demais produtos ou a infraestrutura do estúdio.

O sistema de licença comercial será removido. A licença open source do código é outro documento e precisa ser adicionada. MIT é a recomendação para facilitar adoção; GPLv3 é a alternativa quando a prioridade for manter derivados distribuídos abertos. O proprietário escolheu MIT em 2026-11-09. Usar Studio Baunilha como identificação pública do projeto, preservando os direitos de terceiros.

## Desenho

- Aplicativo: disponibilidade depende de permissões, modelos e provedores configurados. Sem licença, trial, fingerprint comercial, renovação ou telas de compra.
- Download: rota estável atual entrega o DMG gratuito; não aponta para checkout e não exige cadastro.
- Site: download e link de código substituem preço, desconto e compra; todas as 13 localidades publicadas recebem a mudança. Os requisitos de sistema devem refletir a base efetivamente lançada.
- Infraestrutura: retirar execução de checkout, emissão, admin comercial e integrações de pagamento após publicar e validar o aplicativo gratuito. URLs antigas recebem redirecionamento ou resposta explícita de encerramento, sem um formulário comercial residual.
- Migração: manter um caminho comprovado de atualização para quem tem versão antiga bloqueada ou expirada. Não interromper o backend antigo antes de verificar essa atualização e o download manual da nova versão.
- Dados: preservar registros existentes de compras e suporte, sem apagar banco ou prometer que direitos de compradores anteriores desapareceram. Políticas de reembolso antigas não podem ser simplesmente apagadas como se nunca houvesse compras.
- Código aberto: licença do projeto, avisos de terceiros e instruções de compilação separadas de credenciais de distribuição e das licenças dos modelos opcionais.

## Base de trabalho

A main versionada do aplicativo é `bc10862`, versão 1.12.1 build 30; a árvore local tem funcionalidades, dependências e scripts alterados ainda não commitados, incluindo build 32. O release desta tarefa deve partir da base versionada em uma cópia isolada, sem incorporar essas mudanças automaticamente. O site parte de `4ac5e2f`, sem mudanças locais no levantamento. Conferir atualizações dos remotos antes de fixar os SHAs de execução; qualquer diferença material reabre somente o ground afetado.

## Plano por entregas verificáveis

- [x] Aprovar plano e licença do código; registrar a decisão vinculante com ADR.
- [x] Criar branch `codex/free-open-source` em cópia isolada do aplicativo; usar branch própria no site e registrar o estado inicial dos dois.
- [x] Executar os gates existentes na base escolhida; registrar falhas preexistentes antes de alterar código.
- [x] Implementar com teste primeiro o uso sem ativação nos fluxos de configuração inicial, ditado, arquivos e comandos de seleção, preservando bloqueios legítimos de permissões e modelos.
- [x] Remover subsistema e configurações comerciais, interface, diagnósticos e traduções obsoletas; substituir os testes do comportamento comercial removido por testes dos novos critérios.
- [ ] Preparar LICENSE conforme decisão, avisos das dependências, instruções de build sem segredos e documentação coerente; revisar ativos e histórico candidato à publicação. Usar `ad-community-docs` se for necessário documentar contribuição e reporte de vulnerabilidades, sem inventar compromissos de suporte.
- [x] Implementar download gratuito no site, remover scripts Paddle, preços e controles comerciais, atualizar textos e termos afetados, preservar informação aplicável a compras antigas e testar links legados em todas as localidades.
- [x] Preparar a retirada do backend comercial, bindings e variáveis exclusivos; testar respostas sem DB ou chaves comerciais. Preservar os dados existentes fora do runtime retirado.
- [ ] Verificar conta e permissões de Cloudflare e Apple em modo de leitura; localizar a ferramenta Wrangler e resolver o acesso 403 aos endpoints necessários. Conferir o estado real de produtos e links Paddle; não inferir encerramento de venda apenas pela remoção do botão.
- [ ] Rodar testes, lint, localização, build do pacote e do site; executar os cenários reais da avaliação e reter evidências com SHA e hash dos artefatos.
- [ ] Fazer `ad-review` independente do diff e especificação; aplicar `ad-audit` apenas aos riscos não cobertos de cobrança, segurança, exposição de dados e publicação. Registrar cobertura e disposições; revisar somente deltas após correções.
- [ ] Preparar a versão minor seguinte, conforme convenção do projeto, notas de release e pacote final. Conferir versionamento contra o feed real antes de escolher build; não assumir que o build versionado é o maior já distribuído.
- [ ] Submeter o pacote concreto de publicação com diffs finais, licença, fontes a expor, versão, hashes, testes e textos externos já revisados. Cumprir o gate final do proprietário estabelecido no fluxo.
- [ ] Encerrar novas compras no provedor conferido, publicar código revisado e versão gratuita, conferir download e atualização e então publicar o site com anúncio de disponibilidade. Distinguir a parada de novas compras da remoção posterior de webhooks ainda necessários a eventos pendentes.
- [ ] Retirar o runtime comercial após passar o teste de atualização; conferir download, repositório, release, site, links antigos e ausência de chamadas comerciais em produção. Registrar os identificadores de deploy e resultado, sem segredos.

## Critérios de aceitação

- Uso gratuito sem ativação, prazo, limite comercial de Macs ou chamadas a endpoints de licença.
- Configuração inicial e funcionalidades locais funcionam com modelos disponíveis sem servidor comercial; downloads iniciais continuam exigindo rede.
- Permissões do macOS e configuração de provedores continuam verificadas.
- Instalação antiga consegue chegar à versão nova pelo atualizador ou pelo download manual comprovado.
- Site oferece download gratuito e código público sob licença escolhida, sem checkout ou preço em nenhuma localidade publicada.
- Links antigos não permitem novas compras; o estado real do provedor foi conferido.
- Checkout e licenciamento não fazem parte do runtime final do site; registros comerciais existentes são preservados.
- A versão pública tem fonte correspondente e avisos de terceiros; o site do estúdio não é tornado público por consequência.
- Assinatura Apple, notarização e assinatura Sparkle passam no pacote distribuído.
- Revisão independente e auditoria necessária estão resolvidas, com limites de validação explícitos.

## Riscos e como encerrá-los

| Risco | Estado inicial | Evidência que o encerra |
|---|---|---|
| Expor segredo ou conteúdo privado no histórico, tags, issues, PRs, logs ou artefatos | Scan inicial sem achados; revisão de conteúdo pendente | Scan do conjunto exato a expor, revisão humana/independente do conteúdo e metadados; remover ou tratar achados antes da visibilidade pública |
| Publicar alterações de outras tarefas | Árvore local com mudanças preexistentes | Cópia isolada e diff limitado à mudança aprovada |
| Restar bloqueio de licença no aplicativo | Bloqueios encontrados em múltiplos fluxos | Testes comportamentais e uso real sem estado comercial, inclusive Keychain indisponível |
| Cliente antigo perder acesso à atualização | Ainda não testado | Atualização de instalação com licença ausente/expirada; somente depois retirar API |
| Anunciar gratuito enquanto o DMG ainda exige licença | Ainda não há novo DMG | Validar o mesmo hash pelo download público antes do anúncio |
| Página estática antiga continuar vendendo | Checkout é asset Astro além de rota Worker | Testes do servidor montado e inspeção dos HTMLs gerados em cada localidade |
| Expor ou misturar contas pessoais e de trabalho | GitHub pessoal validado; Cloudflare/Apple não conferidos | Usar `ghp` com GH_HOST e remoto github-personal; conferir identidade das demais plataformas sem trocar login global |
| Redistribuir terceiros sob termos errados | Bibliotecas e modelos têm licenças distintas | Inventário de dependências, modelos, recursos e avisos no release |
| Remover dados de compradores ou obrigações de suporte | Estado comercial real desconhecido | Leitura do estado do provedor; preservação de registros e textos aplicáveis a compras anteriores |
| Declarar publicação sem acesso ao site/feed | HEAD retornou 403 neste ambiente | Acesso verificável ao endpoint real com pacote, hash e versão corretos |

## Decisões e gates pendentes

Plano e licença MIT aprovados. Permanecem: acesso real à infraestrutura; conferência de histórico e metadados; versão/build a partir do feed real. MIT, por exemplo, permite que terceiros façam versões comerciais fechadas — gratuidade da distribuição oficial não proíbe isso.

O gate de plano decorre de `AGENTS.ale.md`, seção Feature delivery sequence, item 2: “No implementing commit before the Plan is filled and approved by me.” O gate final de exposição permanece para revisar o conjunto concreto que ficará público e os textos externos. Não há código de implementação desta tarefa até esses gates correspondentes serem satisfeitos.

## Registro de execução — 2026-11-09

- Plano e MIT aprovados pelo proprietário. Aplicativo em cópia isolada e branch própria; a árvore original foi preservada. Site em branch própria. ADR-0001 registra a decisão.
- Base: SwiftLint sem violações; compilação de testes inicialmente impedida pelo componente Metal ausente, instalado antes de executar o novo teste. Site compilou e passou no lint; um teste comercial anterior falhou por token de data fixa expirado.
- TDD: o teste de ditado local sem ativação falhou antes da remoção e passou depois; os testes de redirecionamento e retirada de API também tiveram falha observada antes da implementação.
- Os testes da base continham expectativas de idioma dependentes do sistema e um caminho de executável incompatível com o Swift atual. Corrigidos somente os fixtures e a descoberta do executável necessários ao gate, mantendo as verificações.
- Candidato definido como 1.13 build 33. O feed real foi lido com GET e User-Agent compatível: ainda publica 1.12.1 build 30. HEAD e requisições anteriores deste ambiente retornaram 403; não se trata de evidência de indisponibilidade geral.
- Worker montado localmente: 96 verificações passaram nas 13 localidades. Screenshots desktop e mobile foram inspecionados. Runtime comercial não exige nem acessa DB nos testes de retirada; nenhuma operação foi executada contra o banco real.
- Pacote assinado transcreveu o fixture público jfk.wav do whisper.cpp. A repetição com acesso de rede negado ao processo também produziu transcrição utilizável; hash do fixture: 59dfb9a4acb36fe2a2affc14bacbee2920ff435cb13cc314a08c13f66ba7860e. A versão final recompilada exige seu próprio recibo de artefato.
- Identidade Apple pessoal e perfil Fala Notarization disponíveis. Wrangler sem autenticação na configuração consultada; não houve login, mudança de conta, deploy ou uso de conta temporária. Checkout público da Paddle está configurado em modo live; o estado do catálogo e das transações do provedor ainda não foi acessado.
- Foi solicitada autorização específica para subagente revisor conforme o contrato Codex da skill ad-review; resposta pendente. Nenhuma revisão da autoria foi rotulada como independente.
- Não houve push, publicação, alteração de visibilidade ou retirada de serviços de produção.
