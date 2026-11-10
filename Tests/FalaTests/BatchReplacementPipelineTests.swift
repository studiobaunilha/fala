import XCTest
@testable import FalaCore

@MainActor
final class BatchReplacementPipelineTests: TranscriptionJobTestCase {
    func testSuccessfulAIResultIsCorrectedBeforeSavingFile() async throws {
        try await checkSavedText(model: "fixed", template: .custom, expected: "Eu comunico com Niko.")
    }

    func testAIEchoAppliesRulesOnlyOnceBeforeSavingFile() async throws {
        try await checkSavedText(model: "echo", template: .custom, expected: "Eu comunico com Niko.")
    }

    func testRawFileOutputAppliesRulesOnlyOnce() async throws {
        try await checkSavedText(model: "fixed", template: .raw, expected: "Eu comunico com Niko")
    }

    func testAIFailureKeepsCorrectedFallbackAndWarning() async throws {
        try await checkSavedText(model: "failure", template: .custom, expected: "Eu comunico com Niko")
    }

    private func checkSavedText(model: String, template: DictationTemplate, expected: String) async throws {
        URLProtocol.registerClass(BatchReplacementURLProtocol.self)
        defer { URLProtocol.unregisterClass(BatchReplacementURLProtocol.self) }
        var config = AppConfig()
        config.llmProvider = "openai"
        config.openAIKey = "fala-test-no-network"
        config.openAIModel = model
        config.customModePrompt = "Keep the text and add a period."
        config.replacementRules = [
            ReplacementRule(variants: ["Nico"], replacement: "Niko"),
            ReplacementRule(variants: ["Niko"], replacement: "Nicolau")
        ]
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let outputURL = directory.appendingPathComponent("transcript.txt")
        try Data().write(to: outputURL)
        let job = TranscriptionJob(appSettings: makeTestSettings(config: config))
        let outcome = await job.processConfirmedWindowText(
            "Eu comunico com Nico",
            context: ProcessingContext(config: config, template: template, format: "txt",
                                       outputURL: outputURL, inputURL: directory.appendingPathComponent("audio.wav")),
            promptOverride: nil
        )
        XCTAssertEqual(outcome?.text, expected)
        XCTAssertEqual(try String(contentsOf: outputURL, encoding: .utf8), expected + "\n")
        XCTAssertEqual(outcome?.warning != nil, model == "failure")
    }
}

private class BatchReplacementURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: "Authorization") == "Bearer fala-test-no-network"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            var data = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    data.append(contentsOf: buffer.prefix(count))
                }
            }
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let model = body["model"] as? String
            if model == "failure" {
                client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
                return
            }
            let messages = body["messages"] as? [[String: String]]
            let text = model == "echo" ? (messages?.last?["content"] ?? "") + "." : "Eu comunico com Nico."
            let response = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": text]]]])
            let httpResponse = try XCTUnwrap(HTTPURLResponse(
                url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: nil
            ))
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: response)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
