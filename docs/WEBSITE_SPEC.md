# Fala — distribuição no site

A página do Fala permite conhecer o aplicativo, baixar o instalador oficial gratuitamente e acessar seu código sob licença MIT. Compra, trial e ativação não fazem parte desse percurso.

O código do site pertence ao repositório separado `studiobaunilha/site`. Ele usa Astro com Tailwind, componentes Svelte e um Cloudflare Worker que serve os assets estáticos, resolve idioma e redireciona o download estável. O repositório do site não é tornado público pela abertura do Fala.

## Conteúdo e navegação

A página apresenta os recursos existentes, requisitos de sistema, funcionamento local e uso opcional de provedores externos. O botão de download usa `/download/fala/latest`; o link de código aponta para `https://github.com/studiobaunilha/fala`.

Todas as localidades publicadas usam o mesmo percurso gratuito. Os termos distinguem a licença MIT do projeto das licenças dos modelos e bibliotecas. Informações de compras anteriores permanecem acessíveis, sem oferecer novas compras.

## Rotas antigas

URLs de checkout e sucesso levam à página gratuita equivalente. Endpoints comerciais retirados respondem com orientação para instalar a versão gratuita. A retirada desses endpoints não autoriza apagar registros comerciais existentes.

## Publicação

O site só anuncia a versão gratuita quando o pacote correspondente e o fonte estiverem públicos e verificados. Assinatura Apple, notarização e atualização Sparkle seguem o [processo de distribuição](RELEASE.md).
