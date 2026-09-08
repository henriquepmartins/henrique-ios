// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Henrique",
  platforms: [.iOS(.v26), .macOS(.v26)],
  products: [
    .library(name: "HenriqueCore", targets: ["HenriqueCore"]),
    .library(name: "HenriqueUI", targets: ["HenriqueUI"]),
  ],
  targets: [
    .target(name: "HenriqueCore", resources: [.process("Resources")]),
    .target(name: "HenriqueUI", dependencies: ["HenriqueCore"]),
    .testTarget(
      name: "HenriqueCoreTests", dependencies: ["HenriqueCore"],
      resources: [.copy("Fixtures")]),
  ]
)
