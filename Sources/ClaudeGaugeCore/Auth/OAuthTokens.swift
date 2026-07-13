import Foundation

public struct OAuthTokens: Codable, Equatable, Sendable {
  public let accessToken: String
  public let refreshToken: String?
  public let expiresAt: Date?
  public let subscriptionType: String?
  public let scopes: [String]?
  public let organizationId: String?
  public let organizationName: String?

  public init(
    accessToken: String, refreshToken: String?, expiresAt: Date?, subscriptionType: String?,
    scopes: [String]?, organizationId: String? = nil, organizationName: String? = nil
  ) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
    self.expiresAt = expiresAt
    self.subscriptionType = subscriptionType
    self.scopes = scopes
    self.organizationId = organizationId
    self.organizationName = organizationName
  }

  public var isExpired: Bool {
    guard let expiresAt else { return false }
    return Date() >= expiresAt.addingTimeInterval(-300)
  }
}
