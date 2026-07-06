// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "ClaudeGauge",
  platforms: [.macOS(.v14)],
  targets: [
    .executableTarget(
      name: "ClaudeGauge",
      path: "Sources/ClaudeGauge"
    )
  ]
)
