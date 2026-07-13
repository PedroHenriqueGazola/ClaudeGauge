import ClaudeGaugeCore
import Foundation

enum LoginCommand {
  static func run() async {
    let service = OAuthService()
    let challenge = service.makeChallenge()

    print("Abra a URL abaixo no navegador, autorize e cole o código exibido.")
    print("")
    print(challenge.authorizeURL.absoluteString)
    print("")
    openBrowser(challenge.authorizeURL)

    print("Código: ", terminator: "")
    guard let pasted = readLine(),
      !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      print("Nenhum código informado.")
      exit(1)
    }

    do {
      let tokens = try await service.exchange(pastedCode: pasted, challenge: challenge)
      let store = FileTokenStore()
      var stored = store.load()
      let id = stored.upsert(tokens, id: UUID().uuidString)
      stored.activeId = id
      store.save(stored)
      print("Conectado (plano \(tokens.subscriptionType?.capitalized ?? "ativo")).")
    } catch {
      print((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
      exit(1)
    }
  }

  static func logout() {
    FileTokenStore().save(StoredAccounts())
    print("Contas desconectadas.")
  }

  private static func openBrowser(_ url: URL) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["xdg-open", url.absoluteString]
    try? process.run()
  }
}
