import SwiftUI
import AppKit

struct TranscribeView: View {
    @ObservedObject var job: TranscriptionJob
    @State private var isDropTargeted = false

    var isWorking: Bool {
        if case .idle = job.state { return false }
        if case .done = job.state { return false }
        if case .error = job.state { return false }
        return true
    }

    var body: some View {
        Group {
            if job.queue.isEmpty {
                emptyStateView
            } else {
                formView
            }
        }
        .frame(minWidth: WindowSize.transcribeMinWidth, minHeight: WindowSize.transcribeMinHeight)
        .background(Color(NSColor.windowBackgroundColor))
        .dropDestination(for: URL.self) { items, _ in
            return handleDrop(items)
        } isTargeted: { targeted in
            withAnimation(AnimationConfig.standard) {
                isDropTargeted = targeted
            }
        }
        .overlay {
            if isDropTargeted {
                ZStack {
                    Color.accentColor.opacity(0.1)
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                        .padding(Spacing.sm)
                }
                .allowsHitTesting(false)
            }
        }
    }
    
    private func handleDrop(_ items: [URL]) -> Bool {
        let initialCount = job.queue.count
        job.enqueueInputFiles(items)
        return job.queue.count > initialCount
    }
}
