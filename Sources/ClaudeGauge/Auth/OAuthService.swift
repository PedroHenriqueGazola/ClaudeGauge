import CryptoKit
import Foundation
import Security

struct OAuthChallenge {
  let verifier: String
  let state: String
  let authorizeURL: URL
}

enum OAuthError: LocalizedError {
  case invalidPastedCode
  case stateMismatch
  case exchangeFailed(String)

  var errorDescription: String? {
    switch self {
    case .invalidPastedCode:
      return "Código inválido. Cole o código exibido pela página do Claude."
    case .stateMismatch:
      return "Falha de segurança na verificação (state). Tente entrar de novo."
    case .exchangeFailed(let detail):
      return "Não consegui concluir o login: \(detail)"
    }
  }
}

// Reusa o client_id público do Claude Code — é o único cliente OAuth aceito
// pelo endpoint de uso. Sem isso, o token não é válido em /api/oauth/usage.
struct OAuthService {
  static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
  static let redirectURI = "https://platform.claude.com/oauth/code/callback"
  static let authorizeBase = "https://claude.com/cai/oauth/authorize"
  static let tokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
  static let scopes =
    "org:create_api_key user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload"
  // O endpoint de token devolve um 429 falso pra User-Agent não reconhecido;
  // axios/1.13.6 é o workaround usado pelo ccauth (evita o rate_limit_error).
  private static let userAgent = "axios/1.13.6"

  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func makeChallenge() -> OAuthChallenge {
    let verifier = Self.randomURLSafe(byteCount: 32)
    let state = Self.randomHex(byteCount: 32)
    let challenge = Self.codeChallenge(for: verifier)

    var components = URLComponents(string: Self.authorizeBase)!
    components.queryItems = [
      URLQueryItem(name: "code", value: "true"),
      URLQueryItem(name: "client_id", value: Self.clientID),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
      URLQueryItem(name: "scope", value: Self.scopes),
      URLQueryItem(name: "code_challenge", value: challenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "state", value: state),
    ]

    return OAuthChallenge(verifier: verifier, state: state, authorizeURL: components.url!)
  }

  func exchange(pastedCode: String, challenge: OAuthChallenge) async throws -> OAuthTokens {
    let trimmed = pastedCode.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
    guard let first = parts.first, !first.isEmpty else { throw OAuthError.invalidPastedCode }
    let code = String(first)

    if parts.count > 1, String(parts[1]) != challenge.state {
      throw OAuthError.stateMismatch
    }

    var request = URLRequest(url: Self.tokenURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "grant_type": "authorization_code",
      "client_id": Self.clientID,
      "code": code,
      "state": challenge.state,
      "code_verifier": challenge.verifier,
      "redirect_uri": Self.redirectURI,
    ])

    return try await performTokenRequest(request)
  }

  func refresh(refreshToken: String) async throws -> OAuthTokens {
    var request = URLRequest(url: Self.tokenURL)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
    request.httpBody = Data(
      "grant_type=refresh_token&refresh_token=\(refreshToken)&client_id=\(Self.clientID)".utf8)

    return try await performTokenRequest(request)
  }

  private func performTokenRequest(_ request: URLRequest) async throws -> OAuthTokens {
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      let detail = String(data: data, encoding: .utf8) ?? "sem detalhes"
      throw OAuthError.exchangeFailed(detail)
    }
    return try parseTokens(data)
  }

  private func parseTokens(_ data: Data) throws -> OAuthTokens {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let accessToken = root["access_token"] as? String
    else { throw OAuthError.exchangeFailed("resposta inesperada") }

    let expiresAt = (root["expires_in"] as? NSNumber)
      .map { Date().addingTimeInterval($0.doubleValue) }
    let scopes = (root["scope"] as? String)?
      .split(separator: " ")
      .map(String.init)

    return OAuthTokens(
      accessToken: accessToken,
      refreshToken: root["refresh_token"] as? String,
      expiresAt: expiresAt,
      subscriptionType: subscription(from: root),
      scopes: scopes)
  }

  private func subscription(from root: [String: Any]) -> String? {
    guard let organization = root["organization"] as? [String: Any],
      let type = organization["organization_type"] as? String
    else { return nil }
    let mapping = [
      "claude_max": "max",
      "claude_pro": "pro",
      "claude_team": "team",
      "claude_enterprise": "enterprise",
    ]
    return mapping[type] ?? type
  }

  private static func codeChallenge(for verifier: String) -> String {
    base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
  }

  private static func randomURLSafe(byteCount: Int) -> String {
    base64URL(randomData(byteCount: byteCount))
  }

  private static func randomHex(byteCount: Int) -> String {
    randomData(byteCount: byteCount).map { String(format: "%02x", $0) }.joined()
  }

  private static func randomData(byteCount: Int) -> Data {
    var bytes = [UInt8](repeating: 0, count: byteCount)
    _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
    return Data(bytes)
  }

  private static func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
