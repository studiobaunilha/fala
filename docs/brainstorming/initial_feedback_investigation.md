# Investigação guiada do feedback inicial do Fala

## Resumo

Esta investigação cruza:

- comportamento atual do código
- feedback real de usuário
- documentação oficial da Apple para onboarding, menu bar extras, privacidade, indicadores de progresso e Apple Silicon

Classificação original da investigação:

- `Implementar`
- `Validar como opcional`
- `Deferir`

Leitura prática para priorização de negócio:

- `Bugs / falhas de funcionamento`
- `Coisas previstas de funcionamento`
- `Melhorias / depois`

Referências oficiais:

- [Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)
- [The Menu Bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar)
- [Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy/)
- [Progress Indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators/)
- [Tuning your code’s performance for Apple silicon](https://developer.apple.com/documentation/apple-silicon/tuning-your-code-s-performance-for-apple-silicon)
- [Core ML](https://developer.apple.com/machine-learning/core-ml/)
- [Install and uninstall apps from the internet or a disc on Mac](https://support.apple.com/en-lamr/guide/mac-help/mh35835/mac)
- [Dictate messages and documents on Mac](https://support.apple.com/en-lamr/guide/mac-help/mh40584/mac)
- [Keyboard settings on Mac](https://support.apple.com/is-is/guide/mac-help/kbdm162/mac)

## Matriz de decisão

| Feedback | Comportamento atual | Evidência no código | Referência Apple | Impacto | Esforço | Situação atual |
| --- | --- | --- | --- | --- | --- | --- |
| DMG sem atalho para `Applications` | O DMG agora usa layout guiado com `Applications`, seta e fundo dedicado | `scripts/create-dmg.sh`, `scripts/release.sh`, `scripts/build-notarized-local.sh`, `scripts/style-dmg.applescript` | Apple Support mostra o fluxo de abrir a imagem e mover o app para `Applications` | Alto para primeira impressão | Baixo | `Implementado` |
| Depois do onboarding o usuário precisa “caçar” o app | O app segue como `LSUIElement` e `.accessory`, mas agora conclui o onboarding abrindo Ajustes e melhorando descoberta | `Sources/Fala/Resources/Info.plist`, `Sources/FalaCore/App/AppDelegate.swift`, `Sources/FalaCore/UI/OnboardingWindowController.swift` | HIG de onboarding favorece fluxo curto, contextual e com próximo passo claro | Alto para adoção | Baixo | `Implementado` |
| Ícone da barra de menus genérico | O estado idle agora usa a marca do Fala; o que sobra aqui é só refinamento visual adicional | `Sources/FalaCore/UI/StatusBarController.swift`, `Sources/FalaCore/UI/StatusBarSymbolCatalog.swift` | HIG de menu bar pede clareza e reconhecimento rápido | Médio | Médio | `Melhoria / depois` |
| `Fn/Globe` não funcionou | O Fala deixou de expor `Fn/Globe` como caminho oficial; o produto agora assume apenas atalho global configurável | `Sources/FalaCore/Modes/DictationMode.swift`, `Sources/FalaCore/UI/SettingsView+Ext.swift`, `Sources/FalaCore/Resources/ReleaseNotes.json` | A Apple documenta o gesto, mas ele é opcional e periférico para a proposta do Fala | Baixo no núcleo do produto | Alto | `Melhoria / depois` |
| Falta texto parcial ou feedback textual direto durante a fala | O HUD mostra waveform e estágios, mas não preview textual | `Sources/FalaCore/UI/DictationFeedbackView.swift`, `Sources/FalaCore/UI/DictationFeedbackController.swift` | HIG pede feedback claro; Apple Silicon favorece medir impacto real antes de ampliar UI contínua | Médio para UX, alto risco de complexidade | Alto | `Melhoria / depois` |
| Toggle “colar resultado direto” parece inconsistente | A configuração agora é separada entre ditado comum e resultados de IA/seleção | `Sources/FalaCore/UI/SettingsView+Ext.swift`, `Sources/FalaCore/UI/StatusBarController.swift`, `Sources/FalaCore/Modes/DictationMode.swift` | HIG de clareza favorece controles específicos e semântica precisa | Alto | Baixo | `Implementado` |
| Ditado sobrescreve o clipboard | O pasteboard agora é preservado com snapshot e restauração completos | `Sources/FalaCore/Modes/DictationMode.swift`, `Sources/FalaCore/Modes/DictationMode+LLM.swift`, `Sources/FalaCore/Core/TextInserter.swift`, `Sources/FalaCore/Core/SelectionCapture.swift`, `Sources/FalaCore/Core/PasteboardSnapshot.swift` | Clipboard é parte sensível do fluxo de trabalho e exige previsibilidade | Muito alto | Médio | `Implementado` |
| Falta start/stop por toggle na tecla principal | O fluxo principal continua sendo `push-to-talk`; não há modo toggle no atalho principal | `Sources/FalaCore/Modes/DictationMode.swift`, `README.md`, `docs/SPEC.md` | O ditado nativo aceita encerramento por atalho, mas o posicionamento do Fala ainda é de utilitário rápido e invisível | Médio | Médio | `Melhoria / depois` |
| “uh / hm” continuam aparecendo | Os prompts padrão de pós-processamento agora instruem a remover disfluências comuns quando não mudam o sentido | `Sources/FalaCore/Config/PromptDefaults.swift`, `README.md`, `docs/SPEC.md` | Há valor real aqui, e a capability agora ficou explícita nos modos de limpeza/formatação com IA | Médio | Médio | `Implementado` |

## Decisões desta leva

### Já corrigido nesta leva

- Preservação real do pasteboard com snapshot e restauração completos
- Remoção da cópia automática de comando ou transcrição bruta para o clipboard nos fluxos com IA
- Separação entre:
  - comportamento do ditado comum
  - comportamento dos resultados de IA e seleção
- Abertura dos Ajustes ao concluir o onboarding pela primeira vez
- Ícone idle da menu bar com a marca do Fala
- DMG com `Applications`, layout guiado no Finder e fundo dedicado no padrão “arrastar para instalar”
- Remoção de disfluências comuns como instrução explícita dos prompts padrão de limpeza e formatação com IA

### Classificação prática do que segue aberto

#### Coisas previstas de funcionamento

- Nenhuma pendência nesta categoria para esta leva

#### Melhorias / depois

- Preview textual ao vivo
- Toggle-to-stop no atalho principal
- `Fn/Globe` como atalho opcional no futuro, se fizer sentido revisitar
- Polimentos adicionais da menu bar, se a validação do uso real apontar necessidade

Notas:

- Preview textual ao vivo não é prioridade imediata; hoje ele parece mais mudança de direção de produto do que correção do núcleo.
- O foco de curto prazo continua sendo confiança, previsibilidade e qualidade do texto final.
