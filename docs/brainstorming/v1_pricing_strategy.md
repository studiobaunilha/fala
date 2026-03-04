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

## 2. Análise de Concorrentes (Mercado Mac AI Dictation)
Para definir um preço justo que não desvalorize o produto, mas seja atrativo, mapeamos os três grandes players atuais que resolvem problemas similares no macOS:

- **MacWhisper Pro:** Focado principalmente em arquivos (Batch). Como o Sussurro, é um pagamento único de licença anual. Custa em média **$64 a $79 USD**.
- **Superwhisper:** O concorrente mais direto em termos de "ditado em tempo real offline". Trabalha com assinatura de **$85 USD / ano** ou licença vitalícia absurdamente cara de **$250 USD**.
- **Wispr Flow:** Focado em ditado, mas depende da nuvem (não é offline/privado). Trabalha no modelo SaaS cobrando em média **$144 USD / ano**.

**Conclusão do Mapeamento:** O Sussurro entrega o melhor dos dois mundos (Ditado Global + Transcrição Batch) com formatação de IA integrada, 100% offline. O mercado cobra entre $60 a $144 anuais por isso. Jogar o preço muito abaixo de $30 pode passar a impressão de um aplicativo de baixa qualidade ("cheap tool"). O valor de $39 anuais posiciona o Sussurro como uma alternativa Premium, porém muito mais acessível que a concorrência.

## 3. Tiers de Preço Sugeridos
- **Sustentável (Preço Padrão):** `$39 USD`
  - Mais barato que MacWhisper e Superwhisper, quebrando a barreira de entrada, mas mantendo o status de ferramenta "Pro".
  - Permite margem para promoções como **Desconto de Estudante (50% off - $19.50)** e ativação de Paridade de Poder de Compra (PPP) para países emergentes como o Brasil (via LemonSqueezy).
- **Early Bird (Lançamento):** `$29 USD`
  - Desconto promocional temporário para gerar tração inicial no ProductHunt, X (Twitter) e Reddit.

## 4. Distribuição
- Fora da Mac App Store (evitando taxas de 15-30% e sandboxing restritivo da Apple).
- Vendas processadas via **LemonSqueezy** ou **Paddle**, que gerenciam a infraestrutura de chaves de licença (License Keys) e bloqueio de updates pós-1-ano automaticamente.
- O App vai precisar de uma integração leve para validar a License Key (pode usar a API da plataforma que cuidará do DRM).

## 5. Gatilhos de Marketing
- **Privacidade Extrema:** Processamento 100% offline, áudios não vão para a nuvem. Foco em advogados, médicos e executivos.
- **Velocidade:** Otimizado nativamente para Apple Silicon. Nenhuma perda de bateria ou ventoinhas disparadas.
- **Fluxo Mágico:** Mostrar o "antes e depois" – gravar um áudio desorganizado e o app colar magicamente um texto formatado, revisado e resumido diretamente no editor de texto usando IA.
