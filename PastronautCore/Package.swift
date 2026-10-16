// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PastronautCore",
  platforms: [.macOS(.v14), .iOS(.v17)],
  products: [
    .library(name: "PastronautCore", targets: ["PastronautCore"])
  ],
  targets: [
    .target(name: "PastronautCore"),
    .testTarget(name: "PastronautCoreTests", dependencies: ["PastronautCore"])
  ]
)
