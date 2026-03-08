import AppKit

struct StatusBarDownloadActivity: Equatable {
    let modelName: String
    let fraction: Double

    var displayPercent: Int {
        Int(fraction * 100)
    }
}

struct StatusBarPresentation: Equatable {
    let symbolName: String
    let accessibilityDescription: String
    let toolTip: String?
    let isTemplate: Bool
}

struct StatusBarSymbolConfiguration: Hashable {
    let symbolName: String
    let isTemplate: Bool
}

@MainActor
final class StatusBarSymbolCatalog {
    private var cachedImages: [StatusBarSymbolConfiguration: NSImage] = [:]

    func image(symbolName: String, isTemplate: Bool) -> NSImage? {
        let configuration = StatusBarSymbolConfiguration(
            symbolName: symbolName,
            isTemplate: isTemplate
        )
        if let image = cachedImages[configuration] {
            return image
        }

        let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: nil
        )
        image?.isTemplate = isTemplate
        if let image {
            cachedImages[configuration] = image
        }
        return image
    }
}
