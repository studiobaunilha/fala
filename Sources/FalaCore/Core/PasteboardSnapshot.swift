import AppKit
import Foundation

/// Captures and restores the full general pasteboard contents, including
/// multiple items and non-string payloads such as file URLs or custom UTIs.
@MainActor
struct PasteboardSnapshot {
    private struct ItemPayload: Sendable {
        let representations: [(type: String, data: Data)]
    }

    private let items: [ItemPayload]

    static func capture(from pasteboard: NSPasteboard = .general) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            let payloads = item.types.compactMap { type -> (String, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type.rawValue, data)
            }
            return ItemPayload(representations: payloads)
        }
        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()

        guard !items.isEmpty else {
            return
        }

        let restoredItems = items.compactMap { payload -> NSPasteboardItem? in
            let item = NSPasteboardItem()
            var wroteAnyRepresentation = false

            for representation in payload.representations {
                let type = NSPasteboard.PasteboardType(representation.type)
                wroteAnyRepresentation = item.setData(representation.data, forType: type)
                    || wroteAnyRepresentation
            }

            return wroteAnyRepresentation ? item : nil
        }

        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}
