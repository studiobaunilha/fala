import Foundation
import XCTest
@testable import FalaCore

final class EntitlementAPIClientTests: LicenseManagerTestCase {
    override func tearDown() {
        StubURLProtocol.setRequestHandler(nil)
        super.tearDown()
    }

    func testActivateAcceptsFractionalSecondServerTime() async throws {
        LicensingConfiguration.setTestOverrides(
            backendBaseURL: URL(string: "https://studio.baunilha.dev")
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)

        StubURLProtocol.setRequestHandler { request in
            XCTAssertEqual(request.url?.path, "/api/licenses/activate")

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
            let httpResponse = try XCTUnwrap(response)

            let body = """
            {
              "entitlementToken": "stub-token",
              "email": "buyer@example.com",
              "serverNow": "2026-03-06T18:58:42.271Z",
              "offlineWindowSeconds": 1209600,
              "entitlementKind": "paid"
            }
            """

            return (httpResponse, Data(body.utf8))
        }

        let client = EntitlementAPIClient(session: session)
        let grant = try await client.activate(
            activationCode: "FALA-AAAA-BBBB-CCCC",
            deviceFingerprint: "test-fingerprint",
            machineName: "Test Mac",
            appVersion: "1.0.0"
        )

        XCTAssertEqual(grant.entitlementToken, "stub-token")
        XCTAssertEqual(grant.email, "buyer@example.com")
        XCTAssertEqual(grant.offlineWindowSeconds, 1_209_600)
        XCTAssertEqual(grant.entitlementKind, .paid)
        XCTAssertEqual(grant.serverNow.timeIntervalSince1970, 1_772_823_522.271, accuracy: 0.001)
    }
}

private final class StubURLProtocol: URLProtocol {
    private static let handlerBox = RequestHandlerBox()

    static func setRequestHandler(_ handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?) {
        handlerBox.set(handler)
    }

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handlerBox.get() else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class RequestHandlerBox: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    func set(_ newValue: ((URLRequest) throws -> (HTTPURLResponse, Data))?) {
        lock.lock()
        handler = newValue
        lock.unlock()
    }

    func get() -> ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        lock.lock()
        let current = handler
        lock.unlock()
        return current
    }
}
