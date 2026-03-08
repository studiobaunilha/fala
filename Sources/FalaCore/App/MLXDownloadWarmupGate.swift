import Foundation

@MainActor
public final class MLXDownloadWarmupGate {
    private var completedDownloads: [String: Date] = [:]
    private let cooldownInterval: TimeInterval

    public init(cooldownInterval: TimeInterval = 45) {
        self.cooldownInterval = cooldownInterval
    }

    public func recordCompletion(repoID: String, at date: Date = Date()) {
        completedDownloads[repoID] = date
        purgeExpiredEntries(now: date)
    }

    public func isCoolingDown(repoID: String, now: Date = Date()) -> Bool {
        purgeExpiredEntries(now: now)
        guard let completedAt = completedDownloads[repoID] else {
            return false
        }
        return now.timeIntervalSince(completedAt) < cooldownInterval
    }

    public func clear(repoID: String) {
        completedDownloads.removeValue(forKey: repoID)
    }
}

private extension MLXDownloadWarmupGate {
    func purgeExpiredEntries(now: Date) {
        completedDownloads = completedDownloads.filter { _, completedAt in
            now.timeIntervalSince(completedAt) < cooldownInterval
        }
    }
}
