import Foundation

final class SaveRecoveryLLMCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int { lock.withLock { value } }

    func reset() { lock.withLock { value = 0 } }
    func increment() { lock.withLock { value += 1 } }
}

class SaveRecoveryLLMProtocol: URLProtocol, @unchecked Sendable {
    static let counter = SaveRecoveryLLMCounter()

    override class func canInit(with request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: "Authorization") == "Bearer fala-save-recovery-no-network"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.counter.increment()
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: [
                "choices": [["message": ["content": "Texto aprimorado."]]]
            ])
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
