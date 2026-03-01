# Status de Implementação: Revisão de Modos e Memória

Este documento detalha o estado atual da última solicitação do usuário, separando o que foi entregue, o que está incompleto e o que falta iniciar.

## 1. Configuração por Modo (Customização de LLM)
- **Status**: ✅ **Concluído no Backend/UI**.
- **O que foi feito**:
    - Criada a estrutura `ModeConfig` para armazenar Provedor, Modelo e Prompt por modo.
    - Criada a aba "Modos" na barra lateral para edição granular.
    - Implementado o botão "Restaurar Padrão" para cada prompt.
- **Observação**: Funciona apenas para o Ditado em tempo real no momento.

## 2. Memória de Contexto (Notas da IA)
- **Status**: 🟡 **Incompleto (Lógica de Prompts)**.
- **O que foi feito**:
    - O `ContextManager` agora gera "Notas de IA" (tom, termos, contexto) em vez de histórico bruto.
    - O prompt é atualizado em segundo plano após cada fala.
- **O que falta**:
    - **Diferenciação de Prompt**: Implementar a lógica onde, se a memória estiver vazia, o sistema envia um prompt "Global/Estruturado", e se houver memória, envia um prompt "Complementar/Incremental". Atualmente, ele apenas anexa as notas ao prompt existente.

## 3. Transformação de Texto (Tópicos, Prompt Dev, etc.)
- **Status**: 🟡 **Incompleto (Aplicação)**.
- **O que foi feito**:
    - Os prompts padrão foram atualizados no código para serem mais transformativos.
- **O que falta**:
    - Validar a eficácia dessa transformação. O usuário relatou que o sistema "está apenas transcrevendo". É necessário garantir que o pós-processamento da LLM seja mandatório e eficaz antes da colagem do texto.

## 4. Modo Batch (Processamento de Arquivos)
- **Status**: 🔴 **Não iniciado**.
- **O que falta**:
    - Integrar a seleção de "Modo" (Template) na tela de processamento de arquivos.
    - Garantir que as configurações de `ModeConfig` (prompts customizados) sejam respeitadas ao processar um arquivo MP3/WAV.

## 5. Integração Apple Intelligence (Local)
- **Status**: 🔴 **Não iniciado**.
- **O que falta**:
    - Implementar a ponte real com as APIs de ML local do macOS para que a opção "Apple Intelligence" na UI funcione de fato como as outras.

## 6. Correções de Navegação e Build
- **Status**: ✅ **Concluído**.
- **O que foi feito**:
    - Refatoração da sidebar para evitar o travamento nas páginas de modo.
    - Correção de erros de build e warnings para garantir estabilidade do ambiente de desenvolvimento.
