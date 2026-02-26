import Foundation

public enum AppStoreConnectError: Error {
    case noVersionFound
    case noBuildFound
    case requestFailed(statusCode: Int, body: String)
}

/// https://developer.apple.com/documentation/appstoreconnectapi/appversionstate
public enum AppVersionState: String, Sendable, Decodable {
    case accepted = "ACCEPTED"
    case developerRejected = "DEVELOPER_REJECTED"
    case inReview = "IN_REVIEW"
    case invalidBinary = "INVALID_BINARY"
    case metadataRejected = "METADATA_REJECTED"
    case pendingAppleRelease = "PENDING_APPLE_RELEASE"
    case pendingDeveloperRelease = "PENDING_DEVELOPER_RELEASE"
    case prepareForSubmission = "PREPARE_FOR_SUBMISSION"
    case processingForDistribution = "PROCESSING_FOR_DISTRIBUTION"
    case readyForDistribution = "READY_FOR_DISTRIBUTION"
    case readyForReview = "READY_FOR_REVIEW"
    case rejected = "REJECTED"
    case replacedWithNewVersion = "REPLACED_WITH_NEW_VERSION"
    case waitingForExportCompliance = "WAITING_FOR_EXPORT_COMPLIANCE"
    case waitingForReview = "WAITING_FOR_REVIEW"
}

/// The state, build number, and phased release info for an App Store version.
public struct AppVersionStatus: Sendable {
    public let state: AppVersionState
    public let buildNumber: String?
    public let phasedRelease: PhasedReleaseStatus?
}

/// Client for the App Store Connect API.
public struct API: Sendable {
    let jwt: String
    let appId: String
    let urlSession: URLSession

    public init(jwt: String, appId: String, urlSession: URLSession = .shared) {
        self.jwt = jwt
        self.appId = appId
        self.urlSession = urlSession
    }

    /// Fetches the current state and associated build number for a version of an app.
    /// - Parameter version: The version string to look up.
    /// - Returns: The state and build number of the version.
    public func getAppVersionStatus(version: String) async throws -> AppVersionStatus {
        // https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-appstoreversions
        var components = URLComponents(
            string: "https://api.appstoreconnect.apple.com/v1/apps/\(appId)/appStoreVersions")!
        components.queryItems = [
            URLQueryItem(name: "limit", value: "1"),
            URLQueryItem(name: "filter[versionString]", value: version),
            URLQueryItem(name: "include", value: "build,appStoreVersionPhasedRelease"),
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

        let decoded = try JSONDecoder().decode(AppStoreVersionsResponse.self, from: data)

        guard let appStoreVersion = decoded.data.first else {
            throw AppStoreConnectError.noVersionFound
        }

        guard let state = appStoreVersion.attributes?.appVersionState else {
            throw AppStoreConnectError.noVersionFound
        }

        // Resolve the build number from the included builds via the relationship ID
        let buildId = appStoreVersion.relationships?.build?.data?.id
        var buildNumber: String?
        if let buildId {
            for item in decoded.included ?? [] {
                if case .build(let build) = item, build.id == buildId {
                    buildNumber = build.attributes?.version
                    break
                }
            }
        }

        // Resolve phased release from included via the relationship ID
        let phasedReleaseId = appStoreVersion.relationships?.appStoreVersionPhasedRelease?.data?.id
        var phasedRelease: PhasedReleaseStatus?
        if let phasedReleaseId {
            for item in decoded.included ?? [] {
                if case .phasedRelease(let pr) = item, pr.id == phasedReleaseId,
                   let prState = pr.attributes?.phasedReleaseState {
                    phasedRelease = PhasedReleaseStatus(
                        state: prState,
                        currentDayNumber: pr.attributes?.currentDayNumber,
                        startDate: pr.attributes?.startDate,
                        totalPauseDuration: pr.attributes?.totalPauseDuration
                    )
                    break
                }
            }
        }

        return AppVersionStatus(state: state, buildNumber: buildNumber, phasedRelease: phasedRelease)
    }
}
