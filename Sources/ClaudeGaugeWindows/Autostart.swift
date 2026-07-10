import Foundation
import WinSDK

enum Autostart {
  private static let runKey = "Software\\Microsoft\\Windows\\CurrentVersion\\Run"
  private static let valueName = "ClaudeGauge"

  static var isEnabled: Bool {
    wide(runKey).withUnsafeBufferPointer { key in
      wide(valueName).withUnsafeBufferPointer { name in
        RegGetValueW(
          HKEY_CURRENT_USER, key.baseAddress, name.baseAddress,
          DWORD(RRF_RT_REG_SZ), nil, nil, nil) == ERROR_SUCCESS
      }
    }
  }

  static func setEnabled(_ enabled: Bool) {
    wide(runKey).withUnsafeBufferPointer { key in
      wide(valueName).withUnsafeBufferPointer { name in
        guard enabled else {
          _ = RegDeleteKeyValueW(HKEY_CURRENT_USER, key.baseAddress, name.baseAddress)
          return
        }
        let value = wide(executablePath())
        value.withUnsafeBufferPointer { buffer in
          _ = RegSetKeyValueW(
            HKEY_CURRENT_USER, key.baseAddress, name.baseAddress, DWORD(REG_SZ),
            buffer.baseAddress, DWORD(buffer.count * MemoryLayout<WCHAR>.size))
        }
      }
    }
  }

  static func executablePath() -> String {
    var buffer = [WCHAR](repeating: 0, count: 260)
    let length = GetModuleFileNameW(nil, &buffer, DWORD(buffer.count))
    return String(decoding: buffer.prefix(Int(length)), as: UTF16.self)
  }
}
