import Foundation

extension TranscriptionJob {
    nonisolated func outputIsReserved(_ url: URL, among reservedURLs: Set<URL>) -> Bool {
        let candidate = url.resolvingSymlinksInPath().standardizedFileURL
        let reserved = reservedURLs.map { $0.resolvingSymlinksInPath().standardizedFileURL }
        if reserved.contains(candidate) { return true }
        guard !reserved.isEmpty else { return false }
        guard let candidateIdentifier = outputFileIdentifier(at: candidate) else {
            return FileManager.default.fileExists(atPath: candidate.path)
        }
        return reserved.contains { reservedURL in
            guard let identifier = outputFileIdentifier(at: reservedURL) else { return true }
            return candidateIdentifier.isEqual(identifier)
        }
    }

    private nonisolated func outputFileIdentifier(at url: URL) -> (any NSObjectProtocol)? {
        var currentURL = url
        // Atomic saves replace inodes, so reservations need current filesystem metadata.
        currentURL.removeAllCachedResourceValues()
        return try? currentURL.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
    }

    func retainTranscript(_ result: BatchProcessingResult, for itemID: BatchQueueItem.ID) {
        guard let index = queue.firstIndex(where: { $0.id == itemID }) else { return }
        queue[index].retainedTranscript = BatchRetainedTranscript(
            text: result.fullConfirmedText,
            warning: result.warning
        )
    }

    nonisolated func initializeOutputFile(url: URL, format: String) throws {
        let content = format == "md"
            ? "# \(url.deletingPathExtension().lastPathComponent)\n\n"
            : ""
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    nonisolated func appendToFile(url: URL, text: String) throws {
        let handle = try FileHandle(forWritingTo: url)
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((text + "\n").utf8))
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
    }
    
    nonisolated func overwriteFile(url: URL, text: String) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func saveRetainedTranscript(_ transcript: BatchRetainedTranscript, to outputURL: URL) throws {
        let header = outputFormat == "md"
            ? "# \(outputURL.deletingPathExtension().lastPathComponent)\n\n"
            : ""
        do {
            try overwriteFile(url: outputURL, text: header + transcript.text)
        } catch {
            throw BatchOutputSaveError(detail: error.localizedDescription)
        }
    }
}
