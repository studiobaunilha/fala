# Fala v1.1 — Readiness, Onboarding, Warmup e Quality Gates

## Summary
- Registrar este plano no repositório e executar em etapas curtas, cada uma fechando arquitetura, testes e validação antes da próxima.
- Restrições principais: qualidade e cobertura são prioridade máxima; nenhuma etapa é considerada pronta sem passar lint, testes e build; evitar mocks complexos e preferir testes de maior sinal.
- Decisões travadas: catálogo MLX híbrido; onboarding obrigatório para pré-requisitos essenciais; ocultar incompatibilidades do menu rápido; warmup apenas do engine/modelos selecionados; `mlx-community/Qwen3.5-4B-MLX-4bit` só entra no catálogo curado se passar smoke test real.

## Quality Gates
- `make lint`
- `make test`
- `make check`
- build debug do app sem regressão funcional
- build release antes de fechar o conjunto completo
- `make test-mlx` sempre que tocar em catálogo MLX, loader MLX, warmup MLX ou seleção de modelo MLX

## Core Changes
- Introduzir um núcleo único de prontidão (`RuntimeReadinessEvaluator` + `ReadinessIssue`) para consolidar licença/trial, microfone, acessibilidade, engine válido, modelo Whisper baixado quando necessário, provedor/modelo LLM válido e estado de warmup.
- Tornar alterações restart-required transacionais.
- Bloquear uso sem configuração válida.
- Criar `MLXCatalogService` com presets curados + repo ID customizado.
- Criar `WarmupCoordinator` para aquecer em background o engine de transcrição ativo no launch e o provider/modelo LLM selecionado quando já existirem artefatos locais.
- Reforçar a automação de licença com retry/backoff explícito.
- Criar onboarding separado em janela nativa de primeira execução com checklist essencial.
- Limpar o menu de bandeja e ocultar incompatibilidades de configuração.

## Validation Matrix
- Whisper sem modelo baixado
- Parakeet sem nenhum Whisper local
- MLX selecionado sem modelo local
- licença em trial ativo, grace, needs-connection e expired
- microfone ou acessibilidade ausentes
- cancelar restart restaura seleção anterior
- confirmar restart persiste pendência e relança corretamente
- primeira execução online inicia tentativa automática de trial
- primeira execução offline cai em estado orientado
- modos do tray refletem engine/provider atuais sem alertas indevidos
- smoke test do catálogo curado atual
- smoke específico para `Qwen3.5-4B-MLX-4bit` antes de expor preset fixo
