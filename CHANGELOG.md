# Changelog

Todas as mudanças notáveis do Fala serão documentadas aqui.

## [1.0.1] — 2026-03-06

### Correções

- **Transcrição de arquivo usava motor errado**: `TranscriptionJob` sempre usava Whisper, ignorando a seleção de Parakeet. Agora usa o motor correto.
- **Apple Intelligence respondia em idioma errado**: O modelo ~3B ignorava instruções vagas de idioma no modo "Perguntar à IA". Agora inclui instrução explícita com o idioma configurado.
- **Toggle de diarization desincronizado**: O toggle nos Ajustes e na TranscribeView eram independentes. Agora são a mesma configuração.
- **Modo personalizado escondido com Apple Intelligence**: Em vez de sumir, agora mostra aviso de incompatibilidade (consistente com o modo Traduzir).

### Melhorias

- **Picker de modelo adaptado ao motor**: Escondido para Parakeet (sem variantes), mostra label "Parakeet V3".
- **Labels de default informativos**: "Usar Padrão do Sistema" agora mostra o default ativo entre parênteses (ex: "Large v3 Turbo", "Português").
- **Footer de diarization explícito**: Explica que funciona via pós-processamento com IA, não é detecção acústica, e qualidade depende do modelo.
- **Aviso de modo personalizado**: Banner laranja e ícone ⚠️ quando Apple Intelligence está selecionado — no sidebar, nos detalhes do modo, e no menu bar.

---

## [1.0] — Lançamento Inicial

### Funcionalidades

- Ditado por voz com push-to-talk via atalho global
- Motores de transcrição: Whisper (WhisperKit) e Parakeet V3 (FluidAudio/CoreML)
- Provedores de IA: Apple Intelligence, Gemini, OpenAI, MLX local
- Modos de ditado: Transcrição, Tradução para Inglês, Perguntar à IA, Personalizado
- Transcrição de arquivos de áudio (batch)
- Diarization via pós-processamento com IA
- Substituição de texto (find & replace) com múltiplas variantes
- Licenciamento PRO com trial de 7 dias
- Atualizações automáticas via Sparkle + Cloudflare R2
- Pipeline de release automatizado (`scripts/release.sh`)
- Suporte a 25+ idiomas (Parakeet) e 99+ idiomas (Whisper)
- Janela flutuante com feedback visual durante ditado
- Menu bar com atalhos para todos os modos
