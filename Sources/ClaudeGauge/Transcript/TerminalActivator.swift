import AppKit

// Ao clicar na notificação, traz pra frente o terminal onde a sessão do Claude
// está rodando. O transcript não guarda qual terminal é, então correlaciona
// pelo cwd: acha o processo `claude` naquele diretório e sobe a árvore de
// processos até o primeiro ancestral que é um app (.app), e o ativa. Não foca a
// aba exata (o Warp não expõe API pra isso) — traz o app do terminal pra frente.
enum TerminalActivator {
  static func activate(forCwd cwd: String) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard let pid = terminalPID(forCwd: cwd) else { return }
      DispatchQueue.main.async {
        NSRunningApplication(processIdentifier: pid)?.activate()
      }
    }
  }

  private static func terminalPID(forCwd cwd: String) -> pid_t? {
    let output = runShell(findTerminalScript, environment: ["TARGET_CWD": cwd])
    guard let line = output.split(separator: "\n").first else { return nil }
    return pid_t(line.trimmingCharacters(in: .whitespaces))
  }

  private static let findTerminalScript = """
    for pid in $(/usr/bin/pgrep -x claude); do
      c=$(/usr/sbin/lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | /usr/bin/sed -n 's/^n//p' | /usr/bin/head -1)
      [ "$c" = "$TARGET_CWD" ] || continue
      cur=$pid
      while :; do
        ppid=$(/bin/ps -o ppid= -p "$cur" 2>/dev/null | /usr/bin/tr -d ' ')
        { [ -z "$ppid" ] || [ "$ppid" = 1 ]; } && break
        comm=$(/bin/ps -o comm= -p "$ppid" 2>/dev/null)
        case "$comm" in
          */*.app/Contents/MacOS/*) echo "$ppid"; exit 0 ;;
        esac
        cur=$ppid
      done
    done
    """

  private static func runShell(_ script: String, environment: [String: String]) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", script]
    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      return ""
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
  }
}
