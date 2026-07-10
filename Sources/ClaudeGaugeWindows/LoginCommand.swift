import CRT
import ClaudeGaugeCore
import Foundation
import WinSDK

enum LoginCommand {
  static func run() async {
    attachConsole()
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
      FileTokenStore().save(tokens)
      print("Conectado (plano \(tokens.subscriptionType?.capitalized ?? "ativo")).")
    } catch {
      print((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
      exit(1)
    }
  }

  static func logout() {
    attachConsole()
    FileTokenStore().clear()
    print("Conta desconectada.")
  }

  // Com /SUBSYSTEM:WINDOWS o processo nasce sem console; religa stdin/stdout no do terminal pai.
  private static func attachConsole() {
    guard AttachConsole(DWORD.max) else { return }  // ATTACH_PARENT_PROCESS
    _ = freopen("CONOUT$", "w", stdout)
    _ = freopen("CONOUT$", "w", stderr)
    _ = freopen("CONIN$", "r", stdin)
  }

  private static func openBrowser(_ url: URL) {
    wide("open").withUnsafeBufferPointer { verb in
      wide(url.absoluteString).withUnsafeBufferPointer { target in
        _ = ShellExecuteW(nil, verb.baseAddress, target.baseAddress, nil, nil, SW_SHOWNORMAL)
      }
    }
  }
}
