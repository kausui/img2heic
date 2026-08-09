// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "img2heic",
  platforms: [
    .macOS(.v15)
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.5.0"))
  ],
  targets: [
    .executableTarget(
      name: "img2heic",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser")
      ]
    ),
    .testTarget(
      name: "img2heicTests",
      dependencies: ["img2heic"],
      exclude: [
        "Fixtures/README.md"
      ],
      resources: [
        .copy("Fixtures/IMG_5244.HEIC"),
        .copy("Fixtures/real-sdr-8bit.heif"),
        .copy("Fixtures/real-sdr-10bit-display-p3.heif"),
        .copy("Fixtures/real-orientation-8.heif"),
      ]
    ),
  ]
)
