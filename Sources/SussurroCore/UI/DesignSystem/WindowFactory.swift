import SwiftUI

public struct WindowConfig {
    public let title: String
    public let width: CGFloat
    public let height: CGFloat
    public var styleMask: NSWindow.StyleMask
    public var isResizable: Bool
    public var minSize: NSSize?
    
    public init(
        title: String,
        width: CGFloat,
        height: CGFloat,
        styleMask: NSWindow.StyleMask = [.titled, .closable],
        isResizable: Bool = false,
        minSize: NSSize? = nil
    ) {
        self.title = title
        self.width = width
        self.height = height
        self.styleMask = styleMask
        self.isResizable = isResizable
        self.minSize = minSize
    }
}

public enum WindowFactory {
    @MainActor
    public static func makeWindow<Content: View>(config: WindowConfig, content: Content) -> NSWindow {
        var styleMask = config.styleMask
        if config.isResizable {
            styleMask.insert(.resizable)
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: config.width, height: config.height),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        
        window.title = config.title
        window.isReleasedWhenClosed = false
        window.center()
        
        if let minSize = config.minSize {
            window.minSize = minSize
        }
        
        // Mantém a identidade escura do app, mas deixa o macOS desenhar o fundo padrão da janela e form
        window.appearance = NSAppearance(named: .darkAqua)
        
        window.contentView = NSHostingView(rootView: content)
        
        return window
    }
    
    @MainActor
    public static func show(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
