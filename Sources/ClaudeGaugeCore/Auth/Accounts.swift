import Foundation

// Uma conta conectada = um token OAuth (por organização) + um id estável gerado
// pelo cliente. O id do cliente é a chave (não o org id), pra sobreviver a um
// token legado sem org id; o org id só serve pra deduplicar e rotular.
public struct StoredAccount: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public var tokens: OAuthTokens

  public init(id: String, tokens: OAuthTokens) {
    self.id = id
    self.tokens = tokens
  }

  // Rótulo pra UI: nome da org quando conhecido, senão o plano.
  public var label: String {
    if let name = tokens.organizationName, !name.isEmpty { return name }
    if let plan = tokens.subscriptionType, !plan.isEmpty { return plan.capitalized }
    return "Conta Claude"
  }
}

public struct StoredAccounts: Codable, Equatable, Sendable {
  public var accounts: [StoredAccount]
  public var activeId: String?

  public init(accounts: [StoredAccount] = [], activeId: String? = nil) {
    self.accounts = accounts
    self.activeId = activeId
  }

  public var activeAccount: StoredAccount? {
    accounts.first { $0.id == activeId } ?? accounts.first
  }

  public func account(id: String) -> StoredAccount? {
    accounts.first { $0.id == id }
  }

  // Adiciona ou substitui: se já existe uma conta da mesma org, atualiza o token
  // dela (mantendo o id); senão cria uma nova. Retorna o id da conta afetada.
  @discardableResult
  public mutating func upsert(_ tokens: OAuthTokens, id newId: String) -> String {
    if let orgId = tokens.organizationId,
      let index = accounts.firstIndex(where: { $0.tokens.organizationId == orgId })
    {
      accounts[index].tokens = tokens
      return accounts[index].id
    }
    accounts.append(StoredAccount(id: newId, tokens: tokens))
    return newId
  }

  public mutating func updateTokens(id: String, _ tokens: OAuthTokens) {
    guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
    accounts[index].tokens = tokens
  }

  public mutating func remove(id: String) {
    accounts.removeAll { $0.id == id }
    if activeId == id { activeId = accounts.first?.id }
  }
}

extension StoredAccounts {
  public init?(jsonData: Data) {
    guard let decoded = try? Self.decoder.decode(StoredAccounts.self, from: jsonData) else {
      return nil
    }
    self = decoded
  }

  public func jsonData() -> Data? {
    try? Self.encoder.encode(self)
  }

  // Migração do formato antigo (um único OAuthTokens salvo direto).
  public static func migrating(fromLegacy data: Data, newId: String) -> StoredAccounts? {
    guard let tokens = try? decoder.decode(OAuthTokens.self, from: data) else { return nil }
    return StoredAccounts(accounts: [StoredAccount(id: newId, tokens: tokens)], activeId: newId)
  }

  static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
  }()

  static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    return encoder
  }()
}
