# Sussurro — Diretrizes de Documentação

## 1. Tom e Seriedade
A documentação do **Sussurro** (incluindo o README, SPECs e Notas de Lançamento) deve manter sempre um tom **profissional, direto e sério**. Evite linguagem excessivamente coloquial e não simule conversas com o usuário nos guias técnicos.

## 2. Expressividade Visual e Uso de Emojis
**Regra Mestra: NENHUM EMOJI DEVE SER UTILIZADO NA DOCUMENTAÇÃO TÉCNICA OU PÚBLICA.**

O uso de emojis para representar seções (ex: 🚀, 💡, 🛠) transmite uma impressão excessivamente lúdica e pouco profissional, assemelhando-se demais a saídas automáticas e apelativas geradas por ferramentas de IA generativa (ChatGPT). 

Se houver necessidade de aplicar expressividade visual ou dar destaque a determinado ponto:
- Utilize a formatação Markdown enxuta para destaques (`**negrito**`, `> blockquotes`).
- Utilize **Tabelas** ou elementos unificados do markdown original.
- Para marcações pontuais, use caracteres textuais padrão ou representações estilísticas ASCII (ex: `[*]`, `[+]`, `---`, `➔`), mas sem abusar.

A formatação deve servir puramente ao propósito de organizar o conteúdo e facilitar a leitura horizontal, sem distrações.

## 3. Documentação vs. Especulação (A Regra da Definição)
A documentação oficial do Repositório (arquivos na raiz como o `README.md` ou arquivos dentro de `docs/`) tem uma regra estrita: **A documentação deve conter SEMPRE E APENAS decisões consolidadas, arquitetura confirmada e definições concretas.**

A documentação serve para responder: O que é o produto? Para que ele serve? O que ele resolve? Quais são as features garantidas?

- **NÃO documente especulações.**
- **NÃO faça estimativas ou planos futuros incertos na documentação.**
- **NÃO crie históricos de mudanças de ideia nas SPECs oficiais.**

### 3.1 Onde colocar o resto? (`docs/brainstorming/`)
Tudo o que fugir da regra acima (ideias soltas, planos de alterações, notas não-oficiais, rascunhos de modelo de negócio ou escopo hipotético) deve obrigatoriamente ir para o diretório `docs/brainstorming/`. 

Este é um diretório iterativo e descartável. O que não é oficial ainda, fica lá aguardando validação ou deleção futura.

## 4. UI, UX e Identidade Visual (Design System)
O Sussurro é, e sempre deve parecer, um **Aplicativo Nativo do macOS**. Nossa identidade visual e experiência do usuário são estritamente regidas pelas **Apple Human Interface Guidelines (HIG)**.

Sempre que propormos, revisarmos ou implementarmos qualquer alteração de interface (SwiftUI), devemos garantir que:
- O design pareça pertencer organicamente ao macOS (Sonoma/Sequoia).
- Os padrões de componentização, espaçamento, sombras, e tipografia sigam os componentes nativos da Apple.
- Nenhuma anomalia visual de web-app ou frameworks cross-platform seja emulada. Consulte sempre a documentação de UI da Apple para validação técnica de design.
