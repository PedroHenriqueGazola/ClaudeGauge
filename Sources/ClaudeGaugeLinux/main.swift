import CAyatanaAppIndicator
import CNotify
import ClaudeGaugeCore
import Foundation

switch CommandLine.arguments.dropFirst().first {
case "login":
  await LoginCommand.run()
case "logout":
  LoginCommand.logout()
default:
  gtk_init(nil, nil)
  notify_init("ClaudeGauge")
  let app = TrayApp()
  app.start()
  gtk_main()
}
