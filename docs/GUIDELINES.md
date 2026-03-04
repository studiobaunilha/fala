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

## 3. Estruturação do Diretório `docs/`
Mantenha a organização atômica dos documentos:
* `docs/SPEC.md`: Conterá ÚNICA E EXCLUSIVAMENTE decisões consolidadas, arquitetura confirmada, definições concretas do produto, features já aprovadas e público alvo. Não misture "ideias pro futuro" ou "talvez façamos isso" neste arquivo.
* `docs/brainstorming/`: Este diretório é descartável e iterativo. Nele, despeje rascunhos, especulações sobre planos de negócios, hipóteses e notas desorganizadas. O que não é oficial ainda, não vai para a raiz de `docs`.
