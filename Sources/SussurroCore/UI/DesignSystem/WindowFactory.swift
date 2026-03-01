import SwiftUI

public struct WindowConfig {
    public let title: String
    public let width: CGFloat
    public let height: CGFloat
    public var styleMask: NSWindow.StyleMask
    public var isResizable: Bool
    public var minSize: NSSize?
    public var maxSize: NSSize?
    public var fullSizeContentView: Bool
    public var transparentTitlebar: Bool
    
    public init(
        title: String,
        width: CGFloat,
        height: CGFloat,
        styleMask: NSWindow.StyleMask = [.titled, .closable],
        isResizable: Bool = false,
        minSize: NSSize? = nil,
        maxSize: NSSize? = nil,
        fullSizeContentView: Bool = false,
        transparentTitlebar: Bool = false
    ) {
        self.title = title
        self.width = width
        self.height = height
        self.styleMask = styleMask
        self.isResizable = isResizable
        self.minSize = minSize
        self.maxSize = maxSize
        self.fullSizeContentView = fullSizeContentView
        self.transparentTitlebar = transparentTitlebar
    }
}

public enum WindowFactory {
    @MainActor
    public static func makeWindow<Content: View>(config: WindowConfig, content: Content) -> NSWindow {
        var styleMask = config.styleMask
        if config.isResizable {
            styleMask.insert(.resizable)
        }
        if config.fullSizeContentView {
            styleMask.insert(.fullSizeContentView)
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
        
        if let maxSize = config.maxSize {
            window.maxSize = maxSize
        }
        
        if config.transparentTitlebar {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
        }
        
        // Remove forced dark mode to respect macOS Light/Dark system preferences
        window.appearance = nil
        
        window.contentView = NSHostingView(rootView: content)
        
        return window
    }
    
    @MainActor
    public static func show(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
