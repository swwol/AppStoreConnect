import Foundation
import Testing

@testable import AppStoreConnect

@Suite("AppStoreVersionsResponseTests")
struct AppStoreVersionsResponseTests {
    static let foundMatchJSON = """
        {
            "data": [
                {
                    "type": "appStoreVersions",
                    "id": "2395b439-fccd-4645-95bc-97afbe9e379e",
                    "attributes": {
                        "platform": "IOS",
                        "versionString": "1.0",
                        "appStoreState": "READY_FOR_SALE",
                        "appVersionState": "READY_FOR_DISTRIBUTION",
                        "copyright": "2022 YNC",
                        "releaseType": "MANUAL",
                        "earliestReleaseDate": null,
                        "usesIdfa": null,
                        "downloadable": true,
                        "createdDate": "2022-08-31T09:28:28-07:00"
                    },
                    "relationships": {
                        "build": {
                            "data": {
                                "id": "abcd1234",
                                "type": "builds"
                            }
                        },
                        "appStoreVersionSubmission": {
                            "data": {
                                "type": "appStoreVersionSubmissions",
                                "id": "submission1234"
                            }
                        }
                    }
                }
            ],
            "included": [
                {
                    "type": "builds",
                    "id": "abcd1234",
                    "attributes": {
                        "version": "1234"
                    }
                },
                {
                    "type": "appStoreVersionSubmissions",
                    "id": "submission1234",
                    "relationships": {
                        "appStoreVersion": {
                            "data": {
                                "type": "appStoreVersions",
                                "id": "string"
                            }
                        }
                    }
                }
            ],
            "links": {
                "self": "https://api.appstoreconnect.apple.com/v1/apps/538410698/appStoreVersions"
            },
            "meta": { "paging": { "total": 0, "limit": 1 } }
        }
        """

    @Test func decodesVersionData() throws {
        let data = Data(Self.foundMatchJSON.utf8)
        let response = try JSONDecoder().decode(AppStoreVersionsResponse.self, from: data)

        #expect(response.data.count == 1)
        let version = response.data[0]
        #expect(version.id == "2395b439-fccd-4645-95bc-97afbe9e379e")
        #expect(version.attributes?.appVersionState == .readyForDistribution)
    }

    @Test func decodesBuildRelationship() throws {
        let data = Data(Self.foundMatchJSON.utf8)
        let response = try JSONDecoder().decode(AppStoreVersionsResponse.self, from: data)

        let buildRelationship = response.data[0].relationships?.build
        #expect(buildRelationship?.data?.id == "abcd1234")
        #expect(buildRelationship?.data?.type == "builds")
    }

    @Test func decodesIncludedBuild() throws {
        let data = Data(Self.foundMatchJSON.utf8)
        let response = try JSONDecoder().decode(AppStoreVersionsResponse.self, from: data)

        #expect(response.included?.count == 2)

        // First included item is a build
        guard case .build(let build) = response.included?[0] else {
            Issue.record("Expected first included item to be a build")
            return
        }
        #expect(build.id == "abcd1234")
        #expect(build.attributes?.version == "1234")
    }

    @Test func decodesUnknownIncludedTypesAsUnknown() throws {
        let data = Data(Self.foundMatchJSON.utf8)
        let response = try JSONDecoder().decode(AppStoreVersionsResponse.self, from: data)

        // Second included item is an appStoreVersionSubmission, decoded as unknown
        let secondItem = response.included![1]
        guard case .unknown = secondItem else {
            Issue.record("Expected second included item to be unknown")
            return
        }
    }
}
