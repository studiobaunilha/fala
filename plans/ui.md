# Plano: Design System Raycast-Inspired + Janela Resizable + App Icon

## Contexto

O Sussurro tem duas views SwiftUI (SettingsView, TranscribeView) e dois window controllers com código duplicado, zero design tokens (cores/spacing/fontes hardcoded inline), zero testes de UI, e janela de transcrição pequena/fixa. Precisa:

1. Janela de transcrição maior e redimensionável
2. Design system inspirado no Raycast (essência visual, não pixel-perfect): blur/vibrancy escuro, tokens consistentes, componentes reutilizáveis, animações configuráveis (desabilitáveis em testes), DI, cobertura funcional 100%
3. Ícone waveform estilizada para o app

---

## Estrutura de Arquivos

### Novos
```
Sources/SussurroCore/UI/DesignSystem/
  Tokens.swift              — cores, spacing, radius, tipografia, tamanhos de janela
  AnimationConfig.swift     — toggle global de animações (@MainActor static)
  VibrancyBackground.swift  — NSVisualEffectView → SwiftUI representable
  WindowFactory.swift       — fábrica de NSWindow (elimina duplicação)
  StatusBanner.swift        — componente: spinner + texto de status
  RoleBadge.swift           — componente: capsule "Ditado"/"Batch"

Sources/Sussurro/Resources/
  AppIcon.icns              — ícone waveform (gerado via iconutil)

Tests/SussurroTests/
  DesignTokenTests.swift    — valida escala monotônica, toggle de animação
  WindowFactoryTests.swift  — valida config de janelas
  TranscriptionJobTests.swift — state machine do view model
  AppSettingsTests.swift    — inicialização do view model
```

### Modificados
```
Sources/SussurroCore/UI/SettingsView.swift           — tokens + RoleBadge
Sources/SussurroCore/UI/TranscribeView.swift          — tokens + StatusBanner + animações
Sources/SussurroCore/UI/SettingsWindowController.swift — usa WindowFactory
Sources/SussurroCore/UI/TranscribeWindowController.swift — usa WindowFactory, DI(job:), resizable
Sources/SussurroCore/App/AppDelegate.swift            — cria TranscriptionJob, injeta
Sources/Sussurro/Resources/Info.plist                 — CFBundleIconFile
Makefile                                              — copia .icns no bundle
```

---

## Fase 1: Tokens e Fundação

### `Tokens.swift`

```swift
import SwiftUI

public enum SussurroColors {
    // Semânticas (paleta escura inspirada no Raycast)
    public static let accent       = Color(red: 0.35, green: 0.55, blue: 1.0)
    public static let success      = Color(red: 0.30, green: 0.78, blue: 0.47)
    public static let warning      = Color(red: 1.0,  green: 0.72, blue: 0.25)
    public static let error        = Color(red: 1.0,  green: 0.35, blue: 0.37)
    public static let purple       = Color(red: 0.65, green: 0.45, blue: 0.95)

    // Texto
    public static let textPrimary   = Color.white.opacity(0.95)
    public static let textSecondary = Color.white.opacity(0.55)

    // Superfícies
    public static let surfacePrimary   = Color.white.opacity(0.06)
    public static let surfaceSecondary = Color.white.opacity(0.04)
    public static let border           = Color.white.opacity(0.10)

    // Badges
    public static let badgeDictation = accent.opacity(0.15)
    public static let badgeBatch     = warning.opacity(0.15)
}

public enum Spacing {
    public static let xxs: CGFloat = 2
    public static let xs:  CGFloat = 4
    public static let sm:  CGFloat = 6
    public static let md:  CGFloat = 8
    public static let lg:  CGFloat = 12
    public static let xl:  CGFloat = 16
    public static let xxl: CGFloat = 24
}

public enum CornerRadius {
    public static let sm: CGFloat = 4
    public static let md: CGFloat = 8
    public static let lg: CGFloat = 12
}

public enum Typography {
    public static let title    = Font.system(size: 16, weight: .semibold)
    public static let headline = Font.system(size: 14, weight: .medium)
    public static let body     = Font.system(size: 13)
    public static let caption  = Font.system(size: 11)
    public static let caption2 = Font.system(size: 10, weight: .medium)
    public static let mono     = Font.system(size: 11, design: .monospaced)
}

public enum WindowSize {
    public static let settingsWidth:  CGFloat = 480
    public static let settingsHeight: CGFloat = 560
    public static let transcribeMinWidth:  CGFloat = 520
    public static let transcribeMinHeight: CGFloat = 400
    public static let transcribeDefaultWidth:  CGFloat = 600
    public static let transcribeDefaultHeight: CGFloat = 480
}
```

### `AnimationConfig.swift`

```swift
public enum AnimationConfig {
    @MainActor public static var enabled: Bool = true

    @MainActor public static var standard: Animation? {
        enabled ? .easeInOut(duration: 0.2) : nil
    }
    @MainActor public static var spring: Animation? {
        enabled ? .spring(response: 0.35, dampingFraction: 0.8) : nil
    }
}
```

Mapeamento inline → token:

| Valor inline atual | Token |
|---|---|
| `.font(.caption)` | `Typography.caption` |
| `spacing: 8` | `Spacing.md` |
| `spacing: 12` | `Spacing.lg` |
| `.blue.opacity(0.15)` | `SussurroColors.badgeDictation` |
| `.foregroundStyle(.green)` | `SussurroColors.success` |
| `.foregroundStyle(.red)` | `SussurroColors.error` |
| `.foregroundStyle(.secondary)` | `SussurroColors.textSecondary` |
| `NSRect(...420, 520)` | `WindowSize.settings*` |

---

## Fase 2: Componentes

### `VibrancyBackground.swift`

NSViewRepresentable que wrapa `NSVisualEffectView(.dark, .behindWindow, .active)`.
View modifier `.sussurroBackground()` aplica como background.

### `WindowFactory.swift`

```swift
struct WindowConfig {
    let title: String
    let width: CGFloat
    let height: CGFloat
    var styleMask: NSWindow.StyleMask = [.titled, .closable]
    var isResizable: Bool = false
    var minSize: NSSize? = nil
}

enum WindowFactory {
    @MainActor
    static func makeWindow<Content: View>(config: WindowConfig, content: Content) -> NSWindow
    // Aplica: vibrancy background, .darkAqua appearance, titlebarAppearsTransparent,
    // backgroundColor .clear, center, isReleasedWhenClosed = false

    @MainActor
    static func show(_ window: NSWindow)
    // NSApp.activate(ignoringOtherApps: true) + makeKeyAndOrderFront
}
```

### `RoleBadge.swift`

```swift
struct RoleBadge: View {
    let title: String
    let color: Color
    static let dictation = RoleBadge(title: "Ditado", color: SussurroColors.accent)
    static let batch = RoleBadge(title: "Batch", color: SussurroColors.warning)
    // body: Text + Typography.caption2 + capsule background
}
```

### `StatusBanner.swift`

```swift
struct StatusBanner: View {
    let message: String
    // body: HStack(spacing: Spacing.lg) { ProgressView().controlSize(.small); Text }
}
```

Substitui os dois blocos duplicados em TranscribeView (`.converting` e `.transcribing`).

---

## Fase 3: Integração

### TranscribeWindowController — resizable + DI

```swift
public init(job: TranscriptionJob) { self.job = job }  // DI em vez de criar internamente

// usa WindowFactory.makeWindow com:
config: WindowConfig(
    title: "Transcrever Arquivo — Sussurro",
    width: WindowSize.transcribeDefaultWidth,   // 600 (era 420)
    height: WindowSize.transcribeDefaultHeight, // 480 (era 350)
    isResizable: true,                          // ERA false
    minSize: NSSize(width: 520, height: 400)
)
```

### SettingsWindowController — usa WindowFactory

Substitui `makeWindow()` body inteiro por `WindowFactory.makeWindow(config:content:)`.

### AppDelegate — injeta TranscriptionJob

```swift
let job = TranscriptionJob()
let transcribeCtrl = TranscribeWindowController(job: job)
```

### SettingsView — migra para tokens + RoleBadge

- Substitui todas cores inline por `SussurroColors.*`
- Substitui spacing inline por `Spacing.*`
- Substitui badges duplicados por `RoleBadge.dictation`/`.batch`
- Substitui `.font(.caption)` por `Typography.caption`

### TranscribeView — migra para tokens + StatusBanner

- Substitui blocos `.converting`/`.transcribing` por `StatusBanner(message:)`
- Substitui cores/fonts inline por tokens
- Wrapa transições de estado com `withAnimation(AnimationConfig.standard)`
- Atualiza frame para `WindowSize.transcribeMin*`

---

## Fase 4: Testes

### `DesignTokenTests.swift`
- `testSpacingScaleIsMonotonic` — valida que a escala é crescente
- `testAnimationConfigDisablesAnimations` — toggle false → nil, true → not nil

### `WindowFactoryTests.swift`
- `testWindowFactoryAppliesConfig` — cria janela, verifica title, styleMask, appearance
- `testWindowFactoryResizable` — verifica .resizable no styleMask
- `testWindowFactoryMinSize` — verifica minSize aplicado

### `TranscriptionJobTests.swift`
- `testInitialStateIsIdle`
- `testResetClearsState` — seta inputURL + state, chama reset(), verifica idle
- `testTranscribeRequiresInputURL` — sem inputURL, estado permanece idle
- `testOutputFormatDefaultsFromConfig`

### `AppSettingsTests.swift`
- `testInitFromConfig` — verifica que dictationModel/batchModel/language propagam
- `testSaveUpdatesTranscriber` — chama save, verifica que transcriber recebeu setModel

Padrão de testes: `@unchecked Sendable`, `MainActor.assumeIsolated` em setUp (mesmo padrão dos existentes).

Em todos os testes: `AnimationConfig.enabled = false` no setUp.

---

## Fase 5: App Icon

1. Criar ícone waveform estilizada em 1024x1024 (design minimalista, fundo escuro, waveform em cor accent)
2. Gerar tamanhos necessários: 16, 32, 128, 256, 512, 1024
3. Converter para `.icns` com `iconutil`
4. Colocar em `Sources/Sussurro/Resources/AppIcon.icns`
5. Adicionar `CFBundleIconFile = AppIcon` no Info.plist
6. Atualizar Makefile para copiar `.icns` → `Sussurro.app/Contents/Resources/`

---

## Ordem de Implementação

| # | Tarefa | Depende de |
|---|--------|-----------|
| 1 | `Tokens.swift` + `AnimationConfig.swift` | — |
| 2 | `DesignTokenTests.swift` | 1 |
| 3 | `VibrancyBackground.swift` | 1 |
| 4 | `RoleBadge.swift` + `StatusBanner.swift` | 1 |
| 5 | `WindowFactory.swift` + `WindowFactoryTests.swift` | 1, 3 |
| 6 | `TranscribeWindowController` → WindowFactory + DI + resizable | 5 |
| 7 | `SettingsWindowController` → WindowFactory | 5 |
| 8 | `AppDelegate` → injeta TranscriptionJob | 6 |
| 9 | `TranscribeView` → tokens + StatusBanner + animações | 1, 4 |
| 10 | `SettingsView` → tokens + RoleBadge | 1, 4 |
| 11 | `TranscriptionJobTests.swift` + `AppSettingsTests.swift` | 8, 9, 10 |
| 12 | App Icon (.icns) + Info.plist + Makefile | — |

---

## Verificação

1. `DEVELOPER_DIR=...Xcode... swift test` — todos os testes passam (22 existentes + novos)
2. `DEVELOPER_DIR=...Xcode... swiftlint --strict` — 0 violações
3. `make dev` — rebuild e relançar
4. Janela de transcrição abre em 600x480 e é redimensionável (min 520x400)
5. Ambas as janelas têm fundo escuro com blur/vibrancy
6. Nenhum magic number inline nas views (grep confirma)
7. App icon aparece no Dock (temporariamente) e no Finder
8. AnimationConfig.enabled = false não causa crashes
