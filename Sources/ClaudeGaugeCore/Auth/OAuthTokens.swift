import Foundation

public struct OAuthTokens: Codable, Equatable {
  public let accessToken: String
  public let refreshToken: String?
  public let expiresAt: Date?
  public let subscriptionType: String?
  public let scopes: [String]?

  public init(
    accessToken: String, refreshToken: String?, expiresAt: Date?, subscriptionType: String?,
    scopes: [String]?
  ) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
    self.expiresAt = expiresAt
    self.subscriptionType = subscriptionType
    self.scopes = scopes
  }

  public var isExpired: Bool {
    guard let expiresAt else { return false }
    return Date() >= expiresAt.addingTimeInterval(-300)
  }
}

extension OAuthTokens {
  public init?(jsonData: Data) {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    guard let tokens = try? decoder.decode(OAuthTokens.self, from: jsonData) else { return nil }
    self = tokens
  }

  public func jsonData() -> Data? {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    return try? encoder.encode(self)
  }
}
