# GROUND-0001: Distribuição gratuita e abertura do Fala

**Status:** recorded
**Decision:** Remover o licenciamento comercial do aplicativo e do site, preservar a segurança da distribuição e abrir somente o repositório do aplicativo após os gates de publicação.
**Decision ref:** docs/brainstorming/fala-open-source-plan.md
**Confidence:** Strong
**Stakes:** high × irreversible

## Decision and confidence

O caminho de implementação é remover o subsistema comercial em vez de manter uma licença fictícia ativa, seguindo a separação já existente entre disponibilidade de recursos, permissões e modelos (C1). Preservar assinaturas e atualização por Sparkle segue A1–A2; a referência pública B1–B2 mostra distribuição aberta de um aplicativo de transcrição com gestores de modelos e áudio separados. No site, manter Astro e Worker, trocar compra por download direto e tratar URLs antigas conforme A3–A4 e C2. D1–D2 identificam a introdução das integrações que serão retiradas. A confiança é Strong para esse caminho técnico; não significa autorização nem prontidão para publicação. A licença do projeto, a exposição do histórico e os acessos de distribuição são gates separados no plano.

## Evidence

### E1 — Licenciamento comercial e segurança de distribuição são mecanismos independentes

**Tier:** Primary
**Strength:** Medium
**Provenance:** A1, A2, C1, D1

O Info.plist mantém campos comerciais separados de SUFeedURL e SUPublicEDKey. Apple documenta Developer ID e notarização; Sparkle documenta assinatura EdDSA do arquivo de atualização. Retirar FalaLicensingBaseURL e FalaEntitlementPublicKeyBase64 não exige retirar os mecanismos de segurança. O procedimento deve verificar o DMG final, e não apenas compilar.

### E2 — Remover apenas a tela de compra deixa bloqueios ativos

**Tier:** Primary
**Strength:** Medium
**Provenance:** C1, D1

RuntimeReadinessEvaluator chama licenseIssue nos caminhos de ditado, arquivos e configuração inicial; DictationMode contém verificação adicional; AppDelegate dispara reconciliação. A remoção deve abranger gerenciador, armazenamento comercial, fingerprint, configuração, interface, diagnóstico, traduções e testes diretamente dependentes. Permissões e configuração de modelos permanecem.

### E3 — O site atual inclui processamento comercial no servidor

**Tier:** Primary
**Strength:** Medium
**Provenance:** A3, A4, C2, D2

O Worker contém checkout-config, webhook Paddle, emissão, ativação, trial, renovação, desativação e administração de licenças com D1. Existem páginas estáticas de checkout em todos os idiomas. Como Cloudflare pode servir assets antes do Worker, redirecionar só no código de fetch é insuficiente se o HTML antigo continuar no build. Remover os assets comerciais e testar o servidor local completo, não apenas chamar a função do Worker.

### E4 — Disponibilizar código requer licença explícita e revisão da exposição

**Tier:** Primary
**Strength:** Medium
**Provenance:** A5, A6, A7, B1, C3

O repositório está privado, sem licenseInfo, com permissão ADMIN confirmada na conta pessoal. MIT permite reutilização inclusive fechada; GPLv3 estabelece condições de abertura para distribuição de derivados. A escolha é do proprietário. A documentação GitHub alerta para exposição também de logs e histórico de Actions; um scan de segredos não substitui revisar conteúdo privado. Abertura do site do estúdio não faz parte desta decisão.

### E5 — A licença do aplicativo não substitui as licenças dos modelos e bibliotecas

**Tier:** Primary
**Strength:** Medium
**Provenance:** A8, A9, C4

Bibliotecas instaladas incluem MIT, Apache 2.0 e os avisos específicos do Sparkle. Modelos opcionais do catálogo incluem Gemma e LFM com termos próprios. A futura LICENSE do Fala cobre o código de titularidade do projeto; não rel licencia pesos baixados, bibliotecas ou ativos de terceiros. O inventário de avisos e a orientação de download devem ser verificados na revisão de publicação.

### E6 — As primeiras verificações não estabelecem prontidão de lançamento

**Tier:** Measurement
**Strength:** Medium
**Provenance:** C3, C5

Gitleaks 8.30.1 reportou zero achados na varredura de 288 commits alcançáveis e no diretório Sources. Isso só cobre padrões detectáveis pelo scanner. HEADs para site, download e feed retornaram HTTP 403 neste ambiente. Não é evidência de indisponibilidade geral do serviço e impede afirmar que download e atualização foram validados. A árvore atual tem alterações não commitadas e usa dependências diferentes da main; suas verificações não são intercambiáveis.

## Source register

- **A1:** [Apple Developer ID](https://developer.apple.com/developer-id/), assinatura e notarização para distribuição externa (accessed 2026-11-09 via web).
- **A2:** [Sparkle 2 documentation](https://sparkle-project.org/documentation/), HTTPS, EdDSA e notarização; requisito local from 2.6.4 (accessed 2026-11-09 via web).
- **A3:** [Astro routing](https://docs.astro.build/en/guides/routing/), rotas baseadas em arquivos e redirects; site usa Astro ^5.17.1, documentação corrente consultada sem presumir equivalência total entre versões (accessed 2026-11-09 via web).
- **A4:** [Cloudflare static assets / Worker script](https://developers.cloudflare.com/workers/static-assets/routing/worker-script/), seção Run your Worker script first; compatibilidade local 2026-03-06 (accessed 2026-11-09 via web).
- **A5:** [GitHub visibility](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility), consequências de private para public (accessed 2026-11-09 via web).
- **A6:** [MIT](https://choosealicense.com/licenses/mit/), permissões e avisos de copyright (accessed 2026-11-09 via web).
- **A7:** [GPLv3](https://choosealicense.com/licenses/gpl-3.0/), condições de distribuição e código correspondente (accessed 2026-11-09 via web).
- **A8:** [Gemma model card](https://huggingface.co/mlx-community/gemma-3-text-4b-it-4bit), License: gemma (accessed 2026-11-09 via web).
- **A9:** [LFM model card](https://huggingface.co/mlx-community/LFM2-1.2B-4bit), License: lfm1.0 (accessed 2026-11-09 via web).
- **B1:** [Handy LICENSE](https://raw.githubusercontent.com/cjpais/Handy/main/LICENSE), MIT, linhas 4–11. Trecho: “Permission is hereby granted, free of charge” (accessed 2026-11-09 via web; referência mutável).
- **B2:** [Handy src-tauri/src/lib.rs](https://raw.githubusercontent.com/cjpais/Handy/main/src-tauri/src/lib.rs), linhas 180–209. Trecho de implementação: `TranscriptionManager::new(app_handle, model_manager.clone())`. Gestores de áudio, modelos e transcrição separados, com inicialização de atalhos após permissões. É referência de composição, não código a portar de Rust para Swift (accessed 2026-11-09 via web).
- **C1:** `Sources/FalaCore/App/RuntimeReadinessEvaluator.swift:10`, `Sources/FalaCore/Modes/DictationMode.swift:127`, `Sources/FalaCore/App/AppDelegate.swift:134`, `Sources/Fala/Resources/Info.plist:19`; conferidos também com `git show main:<path>` (accessed 2026-11-09 via local file inspection and git).
- **C2:** Site irmão `worker/index.js:1`, `src/components/FalaLanding.astro:28`, `worker/test/worker-routes.test.js:157`, `wrangler.jsonc:1`; arquivo README define publicação Worker e download estável. Não há exemplo prévio de remoção total; os testes de redirect existentes são o padrão a seguir (accessed 2026-11-09 via local file inspection).
- **C3:** `GH_HOST=github.com ghp repo view studiobaunilha/fala --json nameWithOwner,visibility,licenseInfo,viewerPermission,defaultBranchRef`; PRIVATE, sem licença, ADMIN. `gitleaks git --redact --no-banner --log-opts=--all --report-format=json --report-path=<private-temp-report> .`; exit 0, 288 commits, zero achados. `gitleaks dir --redact --no-banner --timeout=30 Sources`; exit 0, zero achados (accessed 2026-11-09 via CLI; relatórios brutos privados fora do repositório).
- **C4:** `.build/checkouts/argmax-oss-swift/LICENSE:1`, `.build/checkouts/FluidAudio/LICENSE:1`, `.build/checkouts/mlx-swift-lm/LICENSE:1`, `.build/checkouts/Sparkle/LICENSE:1`, `Sources/FalaCore/Resources/MLXCatalog.json:1`; inventário inicial, não licença auditada do release futuro (accessed 2026-11-09 via local file inspection).
- **C5:** HTTP HEAD por urllib para `https://studio.baunilha.dev/fala`, `/download/fala/latest` e `https://pub-e4238720a12f45f68eff0a79f3dda647.r2.dev/appcast.xml`; HTTP 403 para as três URLs. `git status --short`, `git show main:Package.swift` e manifesto local distinguem base de release e trabalho em andamento (accessed 2026-11-09 via CLI).
- **D1:** `git log main --oneline -- Sources/FalaCore/Licensing scripts/release.sh`: `55a0369` introduziu Pro/trial; `4b09778` migrou para tokens; `ea0dd12` automatizou renovação; `ad54728` adicionou notarização. `git branch -a`: main e origin/main, sem implementação concorrente versionada visível (accessed 2026-11-09 via git).
- **D2:** No site, `git log --all --oneline -- worker/index.js src/components/FalaLanding.astro`: `11520cb` migrou Polar para Paddle, `03f6ccb` adicionou backend e checkout, `869bfbf` normalizou respostas. `git branch -a` inclui main e duas branches de configuração Cloudflare, sem caminho já identificado para gratuidade (accessed 2026-11-09 via git).

## Deviations

Não manter uma flag de licença comercial no release: a remoção integral foi definida como resultado do produto. O gate de exposição é a versão nova testada e sua publicação coordenada; não um caminho comercial alternativo no aplicativo. A execução usará uma cópia de trabalho isolada baseada em main, preservando as alterações locais preexistentes. Não portar os detalhes de implementação da referência Rust: o projeto mantém os padrões Swift/SwiftUI já existentes.

## Limitations and reversal

Este registro não valida o aplicativo futuro, não estabelece ausência absoluta de segredos e não autoriza a escolha de licença pelo agente. Autoridade sobre contribuições e ativos, metadados públicos, pacotes finais, contas de infraestrutura e ordens comerciais existentes ainda precisam de conferência antes de tornar o código público ou desativar operações comerciais. Não reescrever histórico nem apagar dados comerciais como efeito implícito desta remoção.

## Audit path

Executar o validador instalado em `ad-ground/scripts/validate-record.mjs` para este arquivo e reabrir as fontes durante a revisão independente. O resultado estrutural não comprova o conteúdo das fontes nem os gates de publicação.
