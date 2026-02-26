import Foundation

/// https://developer.apple.com/documentation/appstoreconnectapi/appstoreversionsresponse
struct AppStoreVersionsResponse: Decodable {
    let data: [AppStoreVersion]
    let included: [Included]?

    enum Included: Decodable {
        case build(Build)
        case phasedRelease(AppStoreVersionPhasedRelease)
        case unknown

        private enum CodingKeys: String, CodingKey {
            case type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try? container.decode(String.self, forKey: .type)
            switch type {
            case "builds":
                self = .build(try Build(from: decoder))
            case "appStoreVersionPhasedReleases":
                self = .phasedRelease(try AppStoreVersionPhasedRelease(from: decoder))
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
        let build: Relationship?
        let appStoreVersionPhasedRelease: Relationship?

        struct Relationship: Decodable {
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

/// https://developer.apple.com/documentation/appstoreconnectapi/phasedreleasestate
public enum PhasedReleaseState: String, Sendable, Decodable {
    case inactive = "INACTIVE"
    case active = "ACTIVE"
    case paused = "PAUSED"
    case complete = "COMPLETE"
}

/// https://developer.apple.com/documentation/appstoreconnectapi/appstoreversionphasedrelease
struct AppStoreVersionPhasedRelease: Decodable {
    let id: String
    let attributes: Attributes?

    struct Attributes: Decodable {
        let phasedReleaseState: PhasedReleaseState?
        let startDate: String?
        let totalPauseDuration: Int?
        let currentDayNumber: Int?
    }
}

public struct PhasedReleaseStatus: Sendable {
    public let state: PhasedReleaseState
    public let currentDayNumber: Int?
    public let startDate: String?
    public let totalPauseDuration: Int?

    /// The rollout percentage based on Apple's fixed 7-day schedule.
    public var rolloutPercentage: Int {
        guard state == .active || state == .paused else {
            return state == .complete ? 100 : 0
        }
        switch currentDayNumber {
        case 1: return 1
        case 2: return 2
        case 3: return 5
        case 4: return 10
        case 5: return 20
        case 6: return 50
        case 7: return 100
        default: return 0
        }
    }
}
