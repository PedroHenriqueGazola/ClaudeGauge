import CAyatanaAppIndicator
import Foundation

final class MenuAction {
  let run: () -> Void

  init(_ run: @escaping () -> Void) {
    self.run = run
  }
}

func gtkCast<T>(_ widget: UnsafeMutablePointer<GtkWidget>?, to type: T.Type)
  -> UnsafeMutablePointer<T>?
{
  guard let widget else { return nil }
  return UnsafeMutableRawPointer(widget).assumingMemoryBound(to: T.self)
}

func appendItem(_ menu: UnsafeMutablePointer<GtkWidget>?, _ item: UnsafeMutablePointer<GtkWidget>?)
{
  gtk_menu_shell_append(gtkCast(menu, to: GtkMenuShell.self), item)
}

func runOnMainLoop(_ work: @escaping () -> Void) {
  let box = Unmanaged.passRetained(MenuAction(work)).toOpaque()
  let callback: GSourceFunc = { data in
    guard let data else { return 0 }
    Unmanaged<MenuAction>.fromOpaque(data).takeRetainedValue().run()
    return 0
  }
  g_idle_add(callback, box)
}
