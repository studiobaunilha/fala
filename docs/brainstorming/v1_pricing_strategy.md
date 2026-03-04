# Estratégia de Precificação e Vendas (v1)

*Nota: Este documento contém ideias e especulações de negócio/marketing e não faz parte da documentação estrita do software.*

## 1. Modelo de Negócio Sugerido
O aplicativo adotará o **Modelo Mac de Software (Pay-Once com licença de atualizações de 1 ano)**.

- O usuário compra o aplicativo e a versão atual é dele **para sempre**.
- A compra garante **1 ano de atualizações gratuitas** (novas features, correções, adaptações para novos macOS).
- Após 1 ano, o aplicativo continua funcionando normalmente, mas para receber novos updates é necessário renovar a licença (geralmente com ~50% de desconto).

### Por que este modelo?
- Assinaturas de software local (SaaS) encontram muita resistência no ecossistema Mac.
- Pagamento único vitalício retira o incentivo financeiro para manutenção a longo prazo.
- Modelos de chave de licença anuais (como Sketch, Parallels, MacWhisper) são o padrão-ouro esperado pela comunidade de produtividade macOS.

## 2. Tiers de Preço
- **Sustentável (Preço Padrão):** `$39 USD`
  - Valor competitivo para ferramentas de produtividade B2B/B2C no ecossistema Mac Apple Silicon.
  - Permite uso de PPP (Purchasing Power Parity) para oferecer descontos localizados (ex: Brasil) via plataforma de vendas.
- **Early Bird (Lançamento):** `$29 USD`
  - Desconto promocional temporário para gerar tração no ProductHunt, X (Twitter) e Reddit.

## 3. Distribuição
- Fora da Mac App Store (evitando taxas de 15-30% e sandboxing restritivo da Apple).
- Vendas processadas via **LemonSqueezy** ou **Paddle**, que gerenciam a infraestrutura de chaves de licença (License Keys) e bloqueio de updates pós-1-ano automaticamente.
- O App vai precisar de uma integração leve para validar a License Key (pode usar a API da plataforma que cuidará do DRM).

## 4. Gatilhos de Marketing
- **Privacidade Extrema:** Processamento 100% offline, áudios não vão para a nuvem. Foco em advogados, médicos e executivos.
- **Velocidade:** Otimizado nativamente para Apple Silicon. Nenhuma perda de bateria ou ventoinhas disparadas.
- **Fluxo Mágico:** Mostrar o "antes e depois" – gravar um áudio desorganizado e o app colar magicamente um texto formatado, revisado e resumido diretamente no editor de texto usando IA.
