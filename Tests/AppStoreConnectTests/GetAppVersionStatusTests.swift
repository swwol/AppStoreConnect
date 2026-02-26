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

@Suite("GetAppVersionStatusTests", .serialized)
struct GetAppVersionStatusTests {
    @Test func returnsStateAndBuildNumber() async throws {
        let json = """
            {
                "data": [{
                    "type": "appStoreVersions",
                    "id": "version-id",
                    "attributes": { "appVersionState": "WAITING_FOR_REVIEW" },
                    "relationships": {
                        "build": { "data": { "id": "build-1", "type": "builds" } }
                    }
                }],
                "included": [{
                    "type": "builds",
                    "id": "build-1",
                    "attributes": { "version": "42" }
                }]
            }
            """
        MockURLProtocol.mockResponseData = Data(json.utf8)
        MockURLProtocol.mockStatusCode = 200

        let status = try await API(
            jwt: "fake-jwt", appId: "app-1", urlSession: makeMockSession()
        ).getAppVersionStatus(version: "1.0")

        #expect(status.state == .waitingForReview)
        #expect(status.buildNumber == "42")
    }

    @Test func returnsNilBuildNumberWhenNoBuildIncluded() async throws {
        let json = """
            {
                "data": [{
                    "type": "appStoreVersions",
                    "id": "version-id",
                    "attributes": { "appVersionState": "PREPARE_FOR_SUBMISSION" },
                    "relationships": {}
                }]
            }
            """
        MockURLProtocol.mockResponseData = Data(json.utf8)
        MockURLProtocol.mockStatusCode = 200

        let status = try await API(
            jwt: "fake-jwt", appId: "app-1", urlSession: makeMockSession()
        ).getAppVersionStatus(version: "1.0")

        #expect(status.state == .prepareForSubmission)
        #expect(status.buildNumber == nil)
    }

    @Test func throwsNoVersionFoundWhenDataIsEmpty() async throws {
        let json = """
            { "data": [] }
            """
        MockURLProtocol.mockResponseData = Data(json.utf8)
        MockURLProtocol.mockStatusCode = 200

        await #expect(throws: AppStoreConnectError.self) {
            _ = try await API(
                jwt: "fake-jwt", appId: "app-1", urlSession: makeMockSession()
            ).getAppVersionStatus(version: "1.0")
        }
    }

    @Test func throwsOnHTTPError() async throws {
        MockURLProtocol.mockResponseData = Data("{}".utf8)
        MockURLProtocol.mockStatusCode = 401

        await #expect(throws: AppStoreConnectError.self) {
            _ = try await API(
                jwt: "fake-jwt", appId: "app-1", urlSession: makeMockSession()
            ).getAppVersionStatus(version: "1.0")
        }
    }
}
