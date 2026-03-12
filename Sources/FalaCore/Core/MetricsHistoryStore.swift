import Foundation

struct MetricsHistoryEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let recordedAt: Date
    let metrics: BatchExecutionMetrics

    init(id: UUID = UUID(), recordedAt: Date = Date(), metrics: BatchExecutionMetrics) {
        self.id = id
        self.recordedAt = recordedAt
        self.metrics = metrics
    }
}

@MainActor
final class MetricsHistoryStore: ObservableObject {
    static let shared = MetricsHistoryStore()

    @Published private(set) var entries: [MetricsHistoryEntry] = []

    private let maxEntries = 50

    private init() {}

    func record(_ metrics: BatchExecutionMetrics) {
        entries.append(MetricsHistoryEntry(metrics: metrics))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }
}
