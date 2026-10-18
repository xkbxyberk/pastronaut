// swift-tools-version: 6.0
// App Store pictures: captioned screenshots and the header / search result asset, from the device screenshots
// that SyncStepTests `storeShots` takes with made-up clips. Run: swift run StoreArt <shots dir> <out dir>
import PackageDescription

let package = Package(
  name: "StoreArt",
  platforms: [.macOS(.v14)],
  dependencies: [.package(path: "../../PastronautCore")],
  targets: [
    .executableTarget(name: "StoreArt", dependencies: [.product(name: "PastronautCore", package: "PastronautCore")])
  ]
)
