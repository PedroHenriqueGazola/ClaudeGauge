import Foundation

// Guarda o conjunto de contas conectadas (uma por organização) + qual é a ativa.
public protocol TokenStoring {
  func load() -> StoredAccounts
  func save(_ accounts: StoredAccounts)
}
