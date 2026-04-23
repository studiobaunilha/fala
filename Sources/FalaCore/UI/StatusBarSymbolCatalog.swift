import AppKit

struct StatusBarDownloadActivity: Equatable {
    let modelName: String
    let fraction: Double

    var displayPercent: Int {
        Int(fraction * 100)
    }
}

enum StatusBarImageDescriptor: Hashable {
    case bundledResource(name: String, fileExtension: String)
    case systemSymbol(String)

    var testingIdentifier: String {
        switch self {
        case let .bundledResource(name, fileExtension):
            "resource:\(name).\(fileExtension)"
        case let .systemSymbol(symbolName):
            symbolName
        }
    }
}

struct StatusBarPresentation: Equatable {
    let imageDescriptor: StatusBarImageDescriptor
    let accessibilityDescription: String
    let toolTip: String?
    let isTemplate: Bool
}

struct StatusBarSymbolConfiguration: Hashable {
    let imageDescriptor: StatusBarImageDescriptor
    let isTemplate: Bool
}

@MainActor
final class StatusBarSymbolCatalog {
    private static let menuBarImageSize = NSSize(width: 18, height: 18)
    private var cachedImages: [StatusBarSymbolConfiguration: NSImage] = [:]

    func image(_ imageDescriptor: StatusBarImageDescriptor, isTemplate: Bool) -> NSImage? {
        let configuration = StatusBarSymbolConfiguration(
            imageDescriptor: imageDescriptor,
            isTemplate: isTemplate
        )
        if let image = cachedImages[configuration] {
            return image
        }

        let image: NSImage?
        switch imageDescriptor {
        case let .bundledResource(name, fileExtension):
            guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension) else {
                return nil
            }
            let bundledImage = NSImage(contentsOf: url)
            bundledImage?.size = Self.menuBarImageSize
            image = bundledImage
        case let .systemSymbol(symbolName):
            image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: nil
            )
        }
        image?.isTemplate = isTemplate
        if let image {
            cachedImages[configuration] = image
        }
        return image
    }
}
