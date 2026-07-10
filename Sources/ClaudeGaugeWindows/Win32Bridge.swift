import Foundation
import WinSDK

let WM_APP_TRAY = UINT(WM_APP) + 1
let WM_APP_RUN = UINT(WM_APP) + 2
let trayIconID: UINT = 1

final class MenuAction {
  let run: () -> Void

  init(_ run: @escaping () -> Void) {
    self.run = run
  }
}

func wide(_ string: String) -> [WCHAR] {
  Array(string.utf16) + [0]
}

// Copia a string pra tuplas de WCHAR de tamanho fixo (szTip, szInfo…), truncando com NUL.
func assign<T>(_ text: String, to buffer: inout T) {
  withUnsafeMutableBytes(of: &buffer) { raw in
    let wchars = raw.bindMemory(to: WCHAR.self)
    let units = Array(text.utf16.prefix(wchars.count - 1)) + [0]
    for (index, unit) in units.enumerated() { wchars[index] = unit }
  }
}

func makeIconData(_ hwnd: HWND?) -> NOTIFYICONDATAW {
  var data = NOTIFYICONDATAW()
  data.cbSize = DWORD(MemoryLayout<NOTIFYICONDATAW>.size)
  data.hWnd = hwnd
  data.uID = trayIconID
  return data
}

// O WndProc roda fora de qualquer contexto Swift — o TrayApp chega via GWLP_USERDATA,
// mesmo padrão Unmanaged dos callbacks C do GtkBridge.
private let trayWndProc: WNDPROC = { hwnd, message, wParam, lParam in
  if message == WM_APP_RUN {
    if let pointer = UnsafeMutableRawPointer(bitPattern: Int(lParam)) {
      Unmanaged<MenuAction>.fromOpaque(pointer).takeRetainedValue().run()
    }
    return 0
  }
  let stored = GetWindowLongPtrW(hwnd, GWLP_USERDATA)
  if stored != 0, let pointer = UnsafeMutableRawPointer(bitPattern: Int(stored)) {
    let app = Unmanaged<TrayApp>.fromOpaque(pointer).takeUnretainedValue()
    if let result = app.handle(message, wParam, lParam) { return result }
  }
  return DefWindowProcW(hwnd, message, wParam, lParam)
}

func createMainWindow(for app: TrayApp) -> HWND? {
  let instance = GetModuleHandleW(nil)
  let className = wide("ClaudeGaugeWindow")

  className.withUnsafeBufferPointer { name in
    var windowClass = WNDCLASSW()
    windowClass.lpfnWndProc = trayWndProc
    windowClass.hInstance = instance
    windowClass.lpszClassName = name.baseAddress
    _ = RegisterClassW(&windowClass)
  }

  let hwnd = className.withUnsafeBufferPointer { name in
    CreateWindowExW(0, name.baseAddress, name.baseAddress, 0, 0, 0, 0, 0, nil, nil, instance, nil)
  }
  if let hwnd {
    _ = SetWindowLongPtrW(
      hwnd, GWLP_USERDATA, LONG_PTR(Int(bitPattern: Unmanaged.passUnretained(app).toOpaque())))
  }
  return hwnd
}

// Análogo do g_idle_add: agenda a closure na thread do message loop.
func runOnMainLoop(_ hwnd: HWND?, _ work: @escaping () -> Void) {
  let box = Unmanaged.passRetained(MenuAction(work)).toOpaque()
  _ = PostMessageW(hwnd, WM_APP_RUN, 0, LPARAM(Int(bitPattern: box)))
}

func appendInfo(_ menu: HMENU?, _ label: String) {
  wide(label).withUnsafeBufferPointer {
    _ = AppendMenuW(menu, UINT(MF_STRING | MF_GRAYED), 0, $0.baseAddress)
  }
}

// Linha informativa: desabilitada (sem hover/clique) mas com texto normal,
// pra não parecer botão desativado (feedback do usuário).
func appendData(_ menu: HMENU?, _ label: String) {
  wide(label).withUnsafeBufferPointer {
    _ = AppendMenuW(menu, UINT(MF_STRING | MF_DISABLED), 0, $0.baseAddress)
  }
}

func appendCommand(_ menu: HMENU?, _ label: String, id: UInt32) {
  wide(label).withUnsafeBufferPointer {
    _ = AppendMenuW(menu, UINT(MF_STRING), UINT_PTR(id), $0.baseAddress)
  }
}

func appendCheck(_ menu: HMENU?, _ label: String, id: UInt32, checked: Bool) {
  let flags = UINT(MF_STRING) | (checked ? UINT(MF_CHECKED) : 0)
  wide(label).withUnsafeBufferPointer {
    _ = AppendMenuW(menu, flags, UINT_PTR(id), $0.baseAddress)
  }
}

func appendSeparator(_ menu: HMENU?) {
  _ = AppendMenuW(menu, UINT(MF_SEPARATOR), 0, nil)
}

func appendSubmenu(_ menu: HMENU?, _ label: String, _ submenu: HMENU?) {
  wide(label).withUnsafeBufferPointer {
    _ = AppendMenuW(
      menu, UINT(MF_POPUP), UINT_PTR(UInt(bitPattern: Int(bitPattern: submenu))), $0.baseAddress)
  }
}
