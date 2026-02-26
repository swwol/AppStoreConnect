import Foundation
import Testing

@testable import AppStoreConnect

private class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var mockResponseData: Data?
    nonisolated(unsafe) static var mockStatusCode: Int = 200

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.mockStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = Self.mockResponseData {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

@Suite("GetBuildBetaStatusTests", .serialized)
struct GetBuildBetaStatusTests {
    @Test func returnsInternalAndExternalStates() async throws {
        let json = """
            {
                "data": [{
                    "type": "builds",
                    "id": "build-1",
                    "relationships": {
                        "buildBetaDetail": {
                            "data": { "id": "detail-1", "type": "buildBetaDetails" }
                        }
                    }
                }],
                "included": [{
                    "type": "buildBetaDetails",
                    "id": "detail-1",
                    "attributes": {
                        "internalBuildState": "IN_BETA_TESTING",
                        "externalBuildState": "WAITING_FOR_BETA_REVIEW"
                    }
                }]
            }
            """
        MockURLProtocol.mockResponseData = Data(json.utf8)
        MockURLProtocol.mockStatusCode = 200

        let status = try await API(
            jwt: "fake-jwt", appId: "app-1", urlSession: makeMockSession()
        ).getBuildBetaStatus(buildNumber: "42")

        #expect(status.internalState == .inBetaTesting)
        #expect(status.externalState == .waitingForBetaReview)
    }

    @Test func returnsNilStatesWhenNoDetailIncluded() async throws {
        let json = """
            {
                "data": [{
                    "type": "builds",
                    "id": "build-1",
                    "relationships": {}
                }]
            }
            """
        MockURLProtocol.mockResponseData = Data(json.utf8)
        MockURLProtocol.mockStatusCode = 200

        let status = try await API(
            jwt: "fake-jwt", appId: "app-1", urlSession: makeMockSession()
        ).getBuildBetaStatus(buildNumber: "42")

        #expect(status.internalState == nil)
        #expect(status.externalState == nil)
    }

    @Test func throwsNoBuildFoundWhenDataIsEmpty() async throws {
        let json = """
            { "data": [] }
            """
        MockURLProtocol.mockResponseData = Data(json.utf8)
        MockURLProtocol.mockStatusCode = 200

        await #expect(throws: AppStoreConnectError.self) {
            _ = try await API(
                jwt: "fake-jwt", appId: "app-1", urlSession: makeMockSession()
            ).getBuildBetaStatus(buildNumber: "42")
        }
    }

    @Test func throwsOnHTTPError() async throws {
        MockURLProtocol.mockResponseData = Data("{}".utf8)
        MockURLProtocol.mockStatusCode = 401

        await #expect(throws: AppStoreConnectError.self) {
            _ = try await API(
                jwt: "fake-jwt", appId: "app-1", urlSession: makeMockSession()
            ).getBuildBetaStatus(buildNumber: "42")
        }
    }
}
