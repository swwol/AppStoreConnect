import Foundation

/// https://developer.apple.com/documentation/appstoreconnectapi/internalbetastate
public enum InternalBetaState: String, Sendable, Decodable {
    case processing = "PROCESSING"
    case processingException = "PROCESSING_EXCEPTION"
    case missingExportCompliance = "MISSING_EXPORT_COMPLIANCE"
    case readyForBetaTesting = "READY_FOR_BETA_TESTING"
    case inBetaTesting = "IN_BETA_TESTING"
    case expired = "EXPIRED"
    case inExportComplianceReview = "IN_EXPORT_COMPLIANCE_REVIEW"
}

/// https://developer.apple.com/documentation/appstoreconnectapi/externalbetastate
public enum ExternalBetaState: String, Sendable, Decodable {
    case processing = "PROCESSING"
    case processingException = "PROCESSING_EXCEPTION"
    case missingExportCompliance = "MISSING_EXPORT_COMPLIANCE"
    case readyForBetaTesting = "READY_FOR_BETA_TESTING"
    case inBetaTesting = "IN_BETA_TESTING"
    case expired = "EXPIRED"
    case readyForBetaSubmission = "READY_FOR_BETA_SUBMISSION"
    case inExportComplianceReview = "IN_EXPORT_COMPLIANCE_REVIEW"
    case waitingForBetaReview = "WAITING_FOR_BETA_REVIEW"
    case inBetaReview = "IN_BETA_REVIEW"
    case betaRejected = "BETA_REJECTED"
    case betaApproved = "BETA_APPROVED"
    case notApplicable = "NOT_APPLICABLE"
}

public struct BuildBetaStatus: Sendable {
    public let internalState: InternalBetaState?
    public let externalState: ExternalBetaState?
}

// MARK: - Response models

struct BuildsResponse: Decodable {
    let data: [BuildEntry]
    let included: [BuildsIncluded]?

    struct BuildEntry: Decodable {
        let id: String
        let relationships: Relationships?

        struct Relationships: Decodable {
            let buildBetaDetail: Relationship?

            struct Relationship: Decodable {
                let data: RelationshipData?

                struct RelationshipData: Decodable {
                    let id: String
                    let type: String
                }
            }
        }
    }

    enum BuildsIncluded: Decodable {
        case buildBetaDetail(BuildBetaDetail)
        case unknown

        private enum CodingKeys: String, CodingKey {
            case type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try? container.decode(String.self, forKey: .type)
            switch type {
            case "buildBetaDetails":
                self = .buildBetaDetail(try BuildBetaDetail(from: decoder))
            default:
                self = .unknown
            }
        }
    }

    struct BuildBetaDetail: Decodable {
        let id: String
        let attributes: Attributes?

        struct Attributes: Decodable {
            let internalBuildState: InternalBetaState?
            let externalBuildState: ExternalBetaState?
        }
    }
}

// MARK: - API extension

extension API {
    /// Fetches the internal and external TestFlight beta states for a build.
    /// - Parameter buildNumber: The build number (version) to look up.
    /// - Returns: The internal and external beta states for the build.
    public func getBuildBetaStatus(buildNumber: String) async throws -> BuildBetaStatus {
        // https://developer.apple.com/documentation/appstoreconnectapi/get-v1-builds
        var components = URLComponents(
            string: "https://api.appstoreconnect.apple.com/v1/builds")!
        components.queryItems = [
            URLQueryItem(name: "filter[app]", value: appId),
            URLQueryItem(name: "filter[version]", value: buildNumber),
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "include", value: "buildBetaDetail"),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)

        let httpResponse = response as! HTTPURLResponse
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AppStoreConnectError.requestFailed(
                statusCode: httpResponse.statusCode, body: body)
        }

        let decoded = try JSONDecoder().decode(BuildsResponse.self, from: data)

        guard let build = decoded.data.first else {
            throw AppStoreConnectError.noBuildFound
        }

        let detailId = build.relationships?.buildBetaDetail?.data?.id
        var internalState: InternalBetaState?
        var externalState: ExternalBetaState?

        if let detailId {
            for item in decoded.included ?? [] {
                if case .buildBetaDetail(let detail) = item, detail.id == detailId {
                    internalState = detail.attributes?.internalBuildState
                    externalState = detail.attributes?.externalBuildState
                    break
                }
            }
        }

        return BuildBetaStatus(internalState: internalState, externalState: externalState)
    }
}
