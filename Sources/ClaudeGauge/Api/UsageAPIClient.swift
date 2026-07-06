import Foundation

enum UsageAPIError: LocalizedError {
  case unauthorized
  case rateLimited(retryAfter: TimeInterval?)
  case endpointUnavailable
  case badResponse(Int)
  case decoding

  var errorDescription: String? {
    switch self {
    case .unauthorized:
      return "Sessão do Claude Code expirou. Rode `claude` pra renovar o login."
    case .rateLimited:
      return "Muitas requisições. Tentando de novo em instantes."
    case .endpointUnavailable:
      return "Endpoint de uso indisponível no momento."
    case .badResponse(let status):
      return "Resposta inesperada da API (HTTP \(status))."
    case .decoding:
      return "Não consegui interpretar a resposta da API."
    }
  }
}

struct UsageAPIClient {
  private let session: URLSession
  private let userAgent = "claude-code/2.1.5"

  init(session: URLSession = .shared) {
    self.session = session
  }

  func fetchUsage(accessToken: String, subscriptionType: String?) async throws -> UsageSnapshot {
    do {
      return try await fetchFromOAuthEndpoint(
        accessToken: accessToken, subscriptionType: subscriptionType)
    } catch UsageAPIError.endpointUnavailable {
      return try await fetchFromMessagesHeaders(
        accessToken: accessToken, subscriptionType: subscriptionType)
    }
  }

  private func fetchFromOAuthEndpoint(accessToken: String, subscriptionType: String?) async throws
    -> UsageSnapshot
  {
    let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    applyOAuthHeaders(&request, accessToken: accessToken)
    request.timeoutInterval = 30

    let (data, response) = try await session.data(for: request)
    try validate(response)
    return try parseUsageJSON(data, subscriptionType: subscriptionType)
  }

  private func fetchFromMessagesHeaders(accessToken: String, subscriptionType: String?) async throws
    -> UsageSnapshot
  {
    let url = URL(string: "https://api.anthropic.com/v1/messages")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    applyOAuthHeaders(&request, accessToken: accessToken)
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.timeoutInterval = 30
    request.httpBody = try JSONSerialization.data(withJSONObject: [
      "model": "claude-haiku-4-5-20251001",
      "max_tokens": 1,
      "messages": [["role": "user", "content": "hi"]],
    ])

    let (_, response) = try await session.data(for: request)
    let http = try validate(response)
    return snapshotFromHeaders(http, subscriptionType: subscriptionType)
  }

  private func applyOAuthHeaders(_ request: inout URLRequest, accessToken: String) {
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
  }

  @discardableResult
  private func validate(_ response: URLResponse) throws -> HTTPURLResponse {
    guard let http = response as? HTTPURLResponse else { throw UsageAPIError.badResponse(-1) }
    switch http.statusCode {
    case 200:
      return http
    case 401, 403:
      throw UsageAPIError.unauthorized
    case 404, 410:
      throw UsageAPIError.endpointUnavailable
    case 429:
      throw UsageAPIError.rateLimited(retryAfter: retryAfter(http))
    default:
      throw UsageAPIError.badResponse(http.statusCode)
    }
  }

  private func parseUsageJSON(_ data: Data, subscriptionType: String?) throws -> UsageSnapshot {
    guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw UsageAPIError.decoding
    }

    func window(_ key: String) -> UsageWindow? {
      guard let object = root[key] as? [String: Any] else { return nil }
      guard let utilization = number(object["utilization"]) else { return nil }
      return UsageWindow(
        percent: clampPercent(utilization),
        resetsAt: parseDate(object["resets_at"] as? String))
    }

    let extra = (root["extra_usage"] as? [String: Any]).map { object in
      ExtraUsage(
        isEnabled: (object["is_enabled"] as? Bool) ?? false,
        usedCredits: number(object["used_credits"]),
        monthlyLimit: number(object["monthly_limit"]),
        currency: object["currency"] as? String)
    }

    return UsageSnapshot(
      fiveHour: window("five_hour"),
      sevenDay: window("seven_day"),
      opusWeekly: window("seven_day_opus"),
      sonnetWeekly: window("seven_day_sonnet"),
      extraUsage: extra,
      subscriptionType: subscriptionType,
      lastUpdated: Date())
  }

  private func snapshotFromHeaders(_ http: HTTPURLResponse, subscriptionType: String?)
    -> UsageSnapshot
  {
    func window(utilizationKey: String, resetKey: String) -> UsageWindow? {
      guard let raw = http.value(forHTTPHeaderField: utilizationKey), let value = Double(raw) else {
        return nil
      }
      let resetsAt = http.value(forHTTPHeaderField: resetKey)
        .flatMap { Double($0) }
        .map { Date(timeIntervalSince1970: $0) }
      return UsageWindow(percent: clampPercent(value * 100), resetsAt: resetsAt)
    }

    return UsageSnapshot(
      fiveHour: window(
        utilizationKey: "anthropic-ratelimit-unified-5h-utilization",
        resetKey: "anthropic-ratelimit-unified-5h-reset"),
      sevenDay: window(
        utilizationKey: "anthropic-ratelimit-unified-7d-utilization",
        resetKey: "anthropic-ratelimit-unified-7d-reset"),
      opusWeekly: nil,
      sonnetWeekly: nil,
      extraUsage: nil,
      subscriptionType: subscriptionType,
      lastUpdated: Date())
  }

  private func number(_ value: Any?) -> Double? {
    if let number = value as? NSNumber { return number.doubleValue }
    if let string = value as? String { return Double(string) }
    return nil
  }

  private func clampPercent(_ value: Double) -> Double {
    min(max(value, 0), 100)
  }

  private func retryAfter(_ http: HTTPURLResponse) -> TimeInterval? {
    guard let value = http.value(forHTTPHeaderField: "Retry-After"), let seconds = Double(value)
    else { return nil }
    return seconds
  }

  private func parseDate(_ string: String?) -> Date? {
    guard let string else { return nil }
    let withFractional = ISO8601DateFormatter()
    withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = withFractional.date(from: string) { return date }

    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: string)
  }
}
