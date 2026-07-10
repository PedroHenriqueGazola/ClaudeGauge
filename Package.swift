// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "ClaudeGauge",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
  ],
  targets: [
    .target(
      name: "ClaudeGaugeCore",
      dependencies: [
        .product(
          name: "Crypto", package: "swift-crypto",
          condition: .when(platforms: [.linux, .windows]))
      ],
      path: "Sources/ClaudeGaugeCore"
    )
  ]
)

#if os(macOS)
  package.targets.append(
    .executableTarget(
      name: "ClaudeGauge",
      dependencies: ["ClaudeGaugeCore"],
      path: "Sources/ClaudeGauge"
    )
  )
#elseif os(Windows)
  package.targets.append(
    .executableTarget(
      name: "claudegauge",
      dependencies: ["ClaudeGaugeCore"],
      path: "Sources/ClaudeGaugeWindows",
      linkerSettings: [
        .unsafeFlags(["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"])
      ]
    )
  )
#else
  package.targets.append(contentsOf: [
    .systemLibrary(
      name: "CAyatanaAppIndicator",
      path: "Sources/CAyatanaAppIndicator",
      pkgConfig: "ayatana-appindicator3-0.1",
      providers: [.apt(["libayatana-appindicator3-dev"])]
    ),
    .systemLibrary(
      name: "CNotify",
      path: "Sources/CNotify",
      pkgConfig: "libnotify",
      providers: [.apt(["libnotify-dev"])]
    ),
    .executableTarget(
      name: "claudegauge",
      dependencies: ["ClaudeGaugeCore", "CAyatanaAppIndicator", "CNotify"],
      path: "Sources/ClaudeGaugeLinux"
    ),
  ])
#endif
