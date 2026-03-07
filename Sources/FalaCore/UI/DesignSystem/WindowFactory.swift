import SwiftUI

private struct LocalizedWindowContent<Content: View>: View {
    @ObservedObject private var localizationObserver = AppLocalizationObserver.shared
    let content: Content

    var body: some View {
        content
            .id(localizationObserver.revision)
            .environment(\.locale, AppLocalization.currentLocale())
    }
}

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
    public var appearance: NSAppearance?
    
    public init(
        title: String,
        width: CGFloat,
        height: CGFloat,
        styleMask: NSWindow.StyleMask = [.titled, .closable],
        isResizable: Bool = false,
        minSize: NSSize? = nil,
        maxSize: NSSize? = nil,
        fullSizeContentView: Bool = false,
        transparentTitlebar: Bool = false,
        appearance: NSAppearance? = nil
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
        self.appearance = appearance
    }
}

public enum WindowFactory {
    @MainActor
    private static func constrainedContent<Content: View>(
        config: WindowConfig,
        content: Content
    ) -> some View {
        content
            .preferredColorScheme(config.appearance == nil ? nil : .dark)
            .frame(
                minWidth: config.minSize?.width,
                maxWidth: config.maxSize?.width == CGFloat.greatestFiniteMagnitude ? nil : config.maxSize?.width,
                minHeight: config.minSize?.height,
                maxHeight: config.maxSize?.height == CGFloat.greatestFiniteMagnitude ? nil : config.maxSize?.height
            )
    }

    @MainActor
    public static func applyContent<Content: View>(
        _ content: Content,
        config: WindowConfig,
        to window: NSWindow
    ) {
        window.title = config.title
        window.appearance = config.appearance
        if config.appearance != nil {
            window.backgroundColor = NSColor.windowBackgroundColor
        }

        window.contentView = NSHostingView(
            rootView: LocalizedWindowContent(
                content: constrainedContent(config: config, content: content)
            )
        )
    }

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
        
        applyContent(content, config: config, to: window)

        return window
    }
    
    @MainActor
    public static func show(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
