import Foundation

protocol AppLifecycleControlling {
    func disableAutomaticTermination(_ reason: String)
    func disableSuddenTermination()
}

extension ProcessInfo: AppLifecycleControlling {}

enum AppLifecyclePolicy {
    static let terminationReason =
        "Fala runs as a menu bar dictation app and must stay available for global shortcuts."

    static func apply(
        to processInfo: AppLifecycleControlling = ProcessInfo.processInfo
    ) {
        processInfo.disableAutomaticTermination(terminationReason)
        processInfo.disableSuddenTermination()
    }
}
