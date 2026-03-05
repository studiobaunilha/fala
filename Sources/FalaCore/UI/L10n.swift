import Foundation

// swiftlint:disable identifier_name
/// Clean Architecture boundary for localized strings outside of SwiftUI.
/// Abstracts the `String(localized:bundle:)` macro so core logic doesn't
/// leak `Bundle.module` dependencies natively.
public func L10n(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}
// swiftlint:enable identifier_name
