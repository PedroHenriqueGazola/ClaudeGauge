import ClaudeGaugeCore
import Foundation
import WinSDK

final class NotificationService {
  private let evaluator = ThresholdEvaluator()
  private let hwnd: HWND?

  init(hwnd: HWND?) {
    self.hwnd = hwnd
  }

  func evaluate(snapshot: UsageSnapshot, thresholds: [Int]) {
    for crossing in evaluator.crossings(for: snapshot, thresholds: thresholds) {
      send(
        title: "Claude · \(crossing.label) em \(Int(crossing.percent))%",
        body: "Você passou de \(crossing.threshold)% do limite.")
    }
  }

  func send(title: String, body: String) {
    var data = makeIconData(hwnd)
    data.uFlags = UINT(NIF_INFO)
    data.dwInfoFlags = DWORD(NIIF_INFO)
    assign(title, to: &data.szInfoTitle)
    assign(body, to: &data.szInfo)
    _ = Shell_NotifyIconW(DWORD(NIM_MODIFY), &data)
  }
}
