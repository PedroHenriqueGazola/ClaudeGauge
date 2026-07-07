import Foundation

// Descobre quais diretórios têm uma sessão do Claude Code de fato aberta,
// contando os processos `claude` vivos por cwd. O transcript sozinho não diz se
// a sessão ainda está rodando (o arquivo fica pra trás quando o terminal
// fecha), e o macOS não deixa ler env (CLAUDE_CODE_SESSION_ID) nem o processo
// mantém o .jsonl aberto — então o cwd do processo é a única correlação
// confiável.
enum LiveSessionProbe {
  static func liveCwdCounts() -> [String: Int] {
    let output = runShell(script)
    return output
      .split(separator: "\n")
      .map(String.init)
      .reduce(into: [:]) { counts, cwd in counts[cwd, default: 0] += 1 }
  }

  private static let script = """
    for pid in $(/bin/ps -Ao pid=,comm= | /usr/bin/awk '$2=="claude"{print $1}'); do
      /usr/sbin/lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | /usr/bin/sed -n 's/^n//p'
    done
    """

  private static func runShell(_ script: String) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", script]

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
