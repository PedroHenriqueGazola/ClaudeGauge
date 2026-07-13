import Foundation

public struct ResolvedAccount: Sendable {
  public let id: String
  public let organizationName: String?
  public let subscriptionType: String?
  public let accessToken: String
}

public struct ResolvedAccounts: Sendable {
  public let accounts: [ResolvedAccount]
  public let activeId: String?
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

final class AuthProvider {
  private let credentialsReader = CredentialsReader()
  private let oauthService = OAuthService()
  private let tokenStore: TokenStoring

  init(tokenStore: TokenStoring) {
    self.tokenStore = tokenStore
  }

  // Resolve todas as contas conectadas, renovando tokens expirados e salvando de
  // volta. Sem contas no app, cai no token do Claude Code (uma conta implícita).
  func currentAccounts() async -> ResolvedAccounts {
    var stored = tokenStore.load()

    if stored.accounts.isEmpty {
      guard let credentials = credentialsReader.read() else {
        return ResolvedAccounts(accounts: [], activeId: nil)
      }
      let fallback = ResolvedAccount(
        id: "claude-code", organizationName: nil,
        subscriptionType: credentials.subscriptionType, accessToken: credentials.accessToken)
      return ResolvedAccounts(accounts: [fallback], activeId: fallback.id)
    }

    var resolved: [ResolvedAccount] = []
    var didRefresh = false
    for account in stored.accounts {
      var tokens = account.tokens
      if tokens.isExpired, let refreshToken = tokens.refreshToken,
        let refreshed = try? await oauthService.refresh(refreshToken: refreshToken)
      {
        tokens = merge(tokens, with: refreshed)
        stored.updateTokens(id: account.id, tokens)
        didRefresh = true
      }
      resolved.append(
        ResolvedAccount(
          id: account.id, organizationName: tokens.organizationName,
          subscriptionType: tokens.subscriptionType, accessToken: tokens.accessToken))
    }
    if didRefresh { tokenStore.save(stored) }

    return ResolvedAccounts(accounts: resolved, activeId: stored.activeAccount?.id)
  }

  private func merge(_ tokens: OAuthTokens, with refreshed: OAuthTokens) -> OAuthTokens {
    OAuthTokens(
      accessToken: refreshed.accessToken,
      refreshToken: refreshed.refreshToken ?? tokens.refreshToken,
      expiresAt: refreshed.expiresAt,
      subscriptionType: refreshed.subscriptionType ?? tokens.subscriptionType,
      scopes: refreshed.scopes ?? tokens.scopes,
      organizationId: refreshed.organizationId ?? tokens.organizationId,
      organizationName: refreshed.organizationName ?? tokens.organizationName)
  }
}
