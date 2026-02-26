import Foundation

/// https://developer.apple.com/documentation/appstoreconnectapi/appstoreversionsresponse
struct AppStoreVersionsResponse: Decodable {
    let data: [AppStoreVersion]
    let included: [Included]?

    enum Included: Decodable {
        case build(Build)
        case unknown

        enum TypeDiscriminator: String, Decodable {
            case builds
        }

        private enum CodingKeys: String, CodingKey {
            case type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try? container.decode(TypeDiscriminator.self, forKey: .type)
            switch type {
            case .builds:
                self = .build(try Build(from: decoder))
            default:
                self = .unknown
            }
        }
    }
}

/// https://developer.apple.com/documentation/appstoreconnectapi/appstoreversion
struct AppStoreVersion: Decodable {
    let id: String
    let attributes: Attributes?
    let relationships: Relationships?

    struct Attributes: Decodable {
        let appVersionState: AppVersionState?
    }

    struct Relationships: Decodable {
        let build: BuildRelationship?

        struct BuildRelationship: Decodable {
            let data: RelationshipData?

            struct RelationshipData: Decodable {
                let id: String
                let type: String
            }
        }
    }
}

/// https://developer.apple.com/documentation/appstoreconnectapi/build
struct Build: Decodable {
    let id: String
    let attributes: Attributes?

    struct Attributes: Decodable {
        let version: String?
    }
}
