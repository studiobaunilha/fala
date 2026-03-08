# Fala — Website Specification (v1)

## 1. Visão Geral do Projeto
A landing page oficial do **Fala** servirá como o principal e único canal de distribuição e vendas (visto que o app operará fora da Mac App Store). 

Em vez de um monorepo, o formato adotado foi o **"Studio Umbrella"**. O código-fonte do website viverá em um repositório isolado e centralizado em `~/Dev/website`, que atuará como o portfólio/estúdio do desenvolvedor, abrigando landing pages individuais para o Fala (`/fala`), CapyNotch (`/capynotch`) e jogos futuros.

## 2. Objetivos Principais
- **Conversão Direta:** Explicar rapidamente o valor do produto e levar ao checkout via Polar.
- **Transmissão de Confiança:** Deixar explícito que o aplicativo é 100% nativo, seguro, offline e focado em privacidade.
- **Performance Extrema:** O site deve carregar instantaneamente, servindo como um espelho da velocidade e otimização do próprio aplicativo.

## 3. Arquitetura e Stack Tecnológica
- **Framework:** Astro (Zero-JS by default, focado em alta performance para conteúdo estático).
- **Estilização:** Tailwind CSS (Utilitário para construção rápida e manutenção simplificada).
- **Hospedagem:** Cloudflare Pages (Deploy direto do repositório GitHub, CDN global, SSL gratuito).
- **Integração de Pagamento:** Polar (via link de checkout direto ou overlay modal).

## 4. UI/UX e Identidade Visual (Design System)
- **Tema:** Prioritariamente Dark Mode ("Apple Modern" / macOS Tahoe aesthetics).
- **Tipografia:** Família tipográfica limpa e geométrica (ex: Inter padrão ou SF Pro native stack).
- **Estética:** *Liquid Glass*, *Negative Space* abundante, micro-interações sutis (hover states reflexivos, bordas suaves) em vez de animações espalhafatosas ou pesadas (WebGL, 3D contínuo). 
- O site deve evocar o mesmo sentimento de um aplicativo utilitário "Pro" da Apple.

## 5. Estrutura da Landing Page (Single Page)
A página será composta pelas seguintes seções (descendo no scroll):

1. **Hero Section (A Promessa Principal)**
   - Header minimalista.
   - Headline focado no problema: "Sua voz. Em texto mágico. Sem nuvem, sem assinaturas." (Exemplo).
   - Subheadline destacando: Nativo para Apple Silicon, Privacidade Extrema, Integração Global.
   - Botão de Call-to-Action (CTA): "Comprar por $39" (com menção à licença de 1 ano abaixo).
   - *Visual:* Grafismo limpo, possivelmente uma captura de tela (mockup clean) ou um GIF super curto e leve mostrando a inserção de texto ocorrendo.

2. **Social Proof / Confiança (Opcional no V1)**
   - "Feito para Advogados, Médicos e Desenvolvedores exigentes."

3. **Features Core (Grid de Benefícios)**
   - **100% Offline:** Sem APIs externas enviando dados de clientes.
   - **System-wide Dictation:** Funciona em qualquer campo de texto (Word, Slack, Xcode).
   - **Transcrições Batch Nativas:** Arraste um arquivo e ganhe o texto pronto para revisar, resumir ou exportar.
   - **LLM Integrado:** Modelos on-device (MLX) ou API opcional para formatar, resumir ou traduzir.

4. **Demonstração do Fluxo (Como Funciona)**
   - Três passos simples: Atalho de Pressionar -> Falar -> Texto Mágico inserido.

5. **Pricing (Preços / Licença)**
   - Caixa unificada explicando claramente o modelo Mac: Pague uma vez, possua a versão para sempre, atualizações gratuitas por 1 ano. Preço ancorado ($39 com possível *Early Bird* explícito). Menção ao desconto PPP (Brasil) ou estudantes.

6. **FAQ (Perguntas Frequentes)**
   - Funciona em Intel? (Não, apenas Apple Silicon).
   - Os dados vão pra nuvem? (Não).
   - O WhisperKit é pesado? (Temos modelos minúsculos e velozes para pouca RAM).

7. **Footer**
   - Links úteis (Termos, Política de Privacidade), contato de suporte, copyright.

## 6. Workflow do Estúdio (Guarda-chuva)
- O código reside em `~/Dev/website`.
- A estilização, footer e componentes (ex: botão de compra Polar) serão construídos genericamente para serem reutilizados nos próximos apps.
- O deploy na Cloudflare Pages apontará para este repositório centralizado, publicando todo o portfólio simultaneamente.
