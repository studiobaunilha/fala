import Foundation

enum DownloadNotificationDispatcher {
    static func postMLXDownloadCompleted(
        repoID: String,
        shortID: String,
        center: NotificationCenter = .default
    ) async {
        await MainActor.run {
            center.post(
                name: .mlxDownloadCompleted,
                object: nil,
                userInfo: ["repoID": repoID, "shortId": shortID]
            )
        }
    }

    static func postWhisperModelDownloadCompleted(
        modelID: String,
        variant: String,
        center: NotificationCenter = .default
    ) async {
        await MainActor.run {
            center.post(
                name: .whisperModelDownloadCompleted,
                object: nil,
                userInfo: ["modelId": modelID, "variant": variant]
            )
        }
    }
}
