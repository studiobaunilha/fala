import XCTest
@testable import SussurroCore

@MainActor
final class IncrementalSavingTests: XCTestCase {

    override func setUp() async throws {
        await MainActor.run { AnimationConfig.enabled = false }
    }

    func testIncrementalProcessingAppendsBlocks() async throws {
        let config = AppConfig.load()
        let transcriber = Transcriber(modelName: "", language: "")
        let settings = AppSettings(config: config, transcriber: transcriber, modelManager: ModelManager())
        let job = TranscriptionJob(appSettings: settings)
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let outputURL = tempDir.appendingPathComponent("output.txt")
        let inputURL = tempDir.appendingPathComponent("input.wav")
        
        // Setup initial file
        try job.initializeOutputFile(url: outputURL, format: "txt", inputURL: inputURL)
        
        let testConfig = AppConfig() // default config, no LLM processing
        
        // Mock stream yielding two distinct windows
        let (stream, continuation) = AsyncStream<TranscriberProgress>.makeStream()
        
        let processingTask = job.createProcessingTask(
            stream: stream,
            config: testConfig,
            template: .raw,
            format: "txt",
            outputURL: outputURL,
            inputURL: inputURL
        )
        
        // First window, incrementally growing
        continuation.yield(TranscriberProgress(text: "<|0.00|> Hello", windowId: 0))
        try await Task.sleep(nanoseconds: 10_000_000)
        continuation.yield(TranscriberProgress(text: "<|0.00|> Hello World", windowId: 0))
        try await Task.sleep(nanoseconds: 10_000_000)
        
        // Second window (forces commit of first window)
        continuation.yield(TranscriberProgress(text: "<|30.00|> Next block", windowId: 1))
        try await Task.sleep(nanoseconds: 10_000_000)
        
        // End of stream (forces commit of second window)
        continuation.finish()
        
        let finalProcessedText = await processingTask.value
        
        // Check final processed text
        XCTAssertEqual(finalProcessedText.trimmingCharacters(in: .whitespacesAndNewlines), """
Hello World
Next block
""")
        
        // Check file content directly to verify `appendToFile` worked
        let fileContent = try String(contentsOf: outputURL, encoding: .utf8)
        XCTAssertEqual(fileContent.trimmingCharacters(in: .whitespacesAndNewlines), """
Hello World
Next block
""")
    }
}
