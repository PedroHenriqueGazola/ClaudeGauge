import Foundation

public protocol TokenStoring {
  func load() -> OAuthTokens?
  func save(_ tokens: OAuthTokens)
  func clear()
}
