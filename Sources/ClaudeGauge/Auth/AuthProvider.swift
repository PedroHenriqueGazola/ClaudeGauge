import Foundation

struct ResolvedAuth {
  let accessToken: String
  let subscriptionType: String?
}

enum AuthError: LocalizedError {
  case noAccount

  var errorDescription: String? {
    switch self {
    case .noAccount:
      return "Nenhuma conta conectada. Entre com sua conta Claude em Configurações, ou rode `claude`."
    }
  }
}

@MainActor
final class AuthProvider {
  private let credentialsReader = CredentialsReader()
  private let oauthService = OAuthService()

  private var cachedAuth: ResolvedAuth?
  private var cacheValidUntil: Date = .distantPast

  private let fallbackCacheWindow: TimeInterval = 15 * 60

  func currentAuth() async throws -> ResolvedAuth {
    if let cachedAuth, Date() < cacheValidUntil {
      return cachedAuth
    }
    let (auth, validUntil) = try await resolve()
    cachedAuth = auth
    cacheValidUntil = validUntil
    return auth
  }

  func invalidate() {
    cachedAuth = nil
    cacheValidUntil = .distantPast
  }

  private func resolve() async throws -> (ResolvedAuth, Date) {
    if let appAuth = try await appTokenAuth() {
      return appAuth
    }
    let auth = try claudeCodeAuth()
    return (auth, Date().addingTimeInterval(fallbackCacheWindow))
  }

  private func appTokenAuth() async throws -> (ResolvedAuth, Date)? {
    guard let tokens = TokenStore.load() else { return nil }
    if !tokens.isExpired {
      return (resolved(from: tokens), validUntil(for: tokens))
    }
    guard let refreshToken = tokens.refreshToken else {
      return (resolved(from: tokens), Date().addingTimeInterval(fallbackCacheWindow))
    }

    let refreshed = try await oauthService.refresh(refreshToken: refreshToken)
    let merged = OAuthTokens(
      accessToken: refreshed.accessToken,
      refreshToken: refreshed.refreshToken ?? tokens.refreshToken,
      expiresAt: refreshed.expiresAt,
      subscriptionType: refreshed.subscriptionType ?? tokens.subscriptionType,
      scopes: refreshed.scopes ?? tokens.scopes)
    TokenStore.save(merged)

    return (resolved(from: merged), validUntil(for: merged))
  }

  private func claudeCodeAuth() throws -> ResolvedAuth {
    guard let credentials = try? credentialsReader.read() else {
      throw AuthError.noAccount
    }
    return ResolvedAuth(
      accessToken: credentials.accessToken,
      subscriptionType: credentials.subscriptionType)
  }

  private func resolved(from tokens: OAuthTokens) -> ResolvedAuth {
    ResolvedAuth(accessToken: tokens.accessToken, subscriptionType: tokens.subscriptionType)
  }

  private func validUntil(for tokens: OAuthTokens) -> Date {
    tokens.expiresAt?.addingTimeInterval(-300) ?? Date().addingTimeInterval(fallbackCacheWindow)
  }
}
