import ClaudeGaugeCore
import Foundation
import WinSDK

switch CommandLine.arguments.dropFirst().first {
case "login":
  await LoginCommand.run()
case "logout":
  LoginCommand.logout()
default:
  let app = TrayApp()
  app.start()
  var message = MSG()
  while GetMessageW(&message, nil, 0, 0) {
    TranslateMessage(&message)
    DispatchMessageW(&message)
  }
}
