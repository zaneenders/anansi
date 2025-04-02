// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "anansi",
  platforms: [
    .macOS("15.0")
  ],
  products: [
    .library(name: "Anansi", targets: ["Anansi"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/swift-server/async-http-client.git",
      from: "1.25.1"),
    .package(
      url: "git@github.com:apple/swift-http-types.git",
      from: "1.3.1"),
  ],
  targets: [
    // MARK: targets
    .target(
      name: "Anansi",
      dependencies: [
        .product(name: "HTTPTypes", package: "swift-http-types"),
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
      ]
    ),
    // MARK: test targets
    .testTarget(name: "AnansiTests", dependencies: ["Anansi"]),
  ]
)
