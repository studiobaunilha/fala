# Análise de Plataformas de Pagamento (Merchant of Record) - 2025

Para desenvolvedores independentes (indie hackers) focados no ecossistema macOS, a escolha do checkout vai muito além da taxa do cartão de crédito. A principal decisão arquitetural é: **Merchant of Record (MoR) vs. Provedor de Pagamento (PSP)**.

## O que é um "Merchant of Record" (MoR)?
Se você usa Stripe nativo, **sua empresa** é a vendedora legal. Isso significa que você precisa calcular, cobrar e recolher o imposto (VAT, GST, Sales Tax) de **todos os países** para onde você vende (o que é um inferno burocrático).

Se você usa um MoR (como Lemon Squeezy ou Paddle), **eles** compram o software de você e revendem para o cliente. Eles assumem 100% da responsabilidade fiscal global, emissão de *invoices* (notas fiscais internacionais), lidar com fraudes, estornos (chargebacks) e conversão de moeda (PPP). Você só saca o dinheiro limpo no fim do mês.

---

## 1. Lemon Squeezy (Recomendado)
A queridinha atual da comunidade Indie (recém-adquirida pela Stripe). Focaram pesadamente em UX e em resolver dores de quem vende produtos digitais "One-Time Payment".

*   **Modelo:** Merchant of Record (Eles lidam com todos os impostos globais).
*   **Recursos Matadores:**
    *   **Geração de Licenças Nativas:** O Lemon Squeezy possui um sistema de *License Keys* interno. Quando o cliente compra, a API deles já gera uma chave de ativação única. Você pode validar essa chave direto no Swift do Sussurro de forma muito fácil.
    *   Checkout muito bonito e fácil de embedar ou linkar direto.
    *   Paridade de Poder de Compra (PPP) programável via API/Link.
*   **Taxas:** ~5% + $0.50 centavos por transação.
*   **Payouts (Saques):** Pagam via transferência local. O dinheiro chega rápido. Comprados pela Stripe, os payouts ficaram ainda mais baratos para muitos países.
*   **Veredito:** É de longe a melhor opção para um app de macOS "Pay Once".

## 2. Paddle
O dinossauro mais robusto do mercado de MoR. Quase todos os apps grandes de Mac (como o Sketch e o MacPaw) no passado usavam Paddle.

*   **Modelo:** Merchant of Record (Eles lidam com todos os impostos globais).
*   **Recursos Matadores:**
    *   Extremamente confiável, infraestrutura parruda de assinaturas (SaaS).
    *   Lida muito bem com faturamento de empresas (B2B invoices).
*   **Taxas:** ~5% + $0.50 centavos por transação.
*   **Desvantagens para o Sussurro:** O processo de aprovação da conta é **muito chato**, lento e às vezes recusam novos apps pequenos. Eles são muito focados em assinaturas recorrentes B2B e o dashboard é bem menos amigável (mais feio) que o Lemon Squeezy. Além disso, os saques demoram semanas.
*   **Veredito:** Ótimo para SaaS corporativo, exagerado e muito burocrático para apps Indie.

## 3. Stripe Checkout (Puro)
O clássico gateway de pagamento direto. Você integra a API deles e recebe pagamentos do mundo todo.

*   **Modelo:** PSP (Payment Service Provider). **Você é o vendedor legal.**
*   **Recursos Matadores:**
    *   Taxa inicial muito mais barata (geralmente em torno de ~2.9% + $0.30).
    *   Controle absoluto de toda a experiência e do frontend.
*   **A "Dor de Cabeça":** Como você não é um MoR, a menos que adicione produtos super caros no ecossistema da Stripe (como o Stripe Tax), **você** é responsável por declarar o IVA na Europa, recolher ICMS, lidar com todas as normas fiscais variadas pelo mundo. E você teria que programar um gerador de *License Keys* de Mac por conta própria no backend.
*   **Veredito:** Trabalhoso demais para "Solo devs" lidarem no início. Pode causar risco contábil vendendo globalmente sem planejamento.

---

### Conclusão e Próximos Passos
Para um lançamento de $39 (com descontos locais PPP e Early Bird para $29) em um app macOS com Licença Perpétua + 1 Ano de Updates, **a recomendação absoluta é o Lemon Squeezy**.

Eles vão te dar o painel de vendas, resolver os impostos automáticos na conversão pra Reais, Dólares ou Euros, e de quebra ainda geram a "Chave de Ativação" que a gente vai codificar dentro do app do Sussurro em Swift para bater na API deles e garantir que só quem comprou consegue usar o produto offline.
