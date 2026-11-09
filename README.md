# Fala

O Fala é um aplicativo nativo de ditado e transcrição para macOS com Apple Silicon. A distribuição oficial é gratuita e o código do projeto está sob a [licença MIT](LICENSE), sem ativação, período de avaliação ou limite comercial de dispositivos.

A transcrição principal roda localmente no Mac. O pós-processamento pode usar modelos locais ou provedores de API configurados pelo usuário. Esses provedores opcionais podem cobrar pelo uso de suas próprias APIs.

## Uso

- Ditado: mantenha o atalho pressionado, fale e solte para transcrever e inserir o texto no aplicativo em foco.
- Arquivos: selecione áudio ou vídeo para transcrever, revisar e exportar como texto ou Markdown.
- Pós-processamento: use instruções para limpar, formatar, resumir ou traduzir o texto com um provedor configurado.
- Seleção e IA: aplique uma instrução digitada ou falada ao texto selecionado.
- Personalização: configure modelos, idioma, prompts e regras de substituição.

O aplicativo precisa das permissões de microfone e acessibilidade para ditado e inserção de texto. O download inicial dos modelos exige internet; depois disso, os fluxos com modelos locais não dependem de um servidor comercial.

## Instalação

Consulte o [site oficial](https://studio.baunilha.dev/fala) para o pacote de instalação. Use o DMG oficial para instalar em `Applications`. As atualizações são distribuídas pelo atualizador Sparkle integrado.

Requisitos desta base: macOS 14 ou superior e Apple Silicon. O consumo de memória e o tamanho dos downloads variam com os modelos selecionados.

## Compilar e verificar

Use Xcode com as ferramentas de linha de comando e o componente Metal, além do SwiftLint. Confira os termos dos modelos antes de redistribuir seus arquivos.

```bash
git clone https://github.com/studiobaunilha/fala.git
cd fala
make check
bash scripts/build-app.sh release --app-dir "$PWD/.build/release-artifacts/Fala.app"
```

A compilação local não exige chave comercial. O empacotamento usa uma identidade Apple disponível ou assinatura local conforme `scripts/codesign-identity.sh`. A distribuição oficial exige Developer ID, notarização e assinatura Sparkle; suas credenciais privadas não fazem parte do repositório. O processo oficial está em [docs/RELEASE.md](docs/RELEASE.md).

## Diagnóstico por linha de comando

```bash
fala transcribe /caminho/para/audio.m4a --profile
```

O modo `--profile` informa os tempos de preparo, carregamento do modelo e transcrição. Para conferir somente a preparação de áudio, adicione `--prepare-only`.

## Licenças

A MIT rege o código de titularidade do projeto e permite uso, modificação e redistribuição, inclusive comercial, preservando seus avisos. Bibliotecas e modelos de terceiros mantêm seus próprios termos. Os [avisos de terceiros](Sources/FalaCore/Resources/ThirdPartyNotices.txt) também acompanham o aplicativo em Sobre.
