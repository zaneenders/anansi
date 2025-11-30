// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "anansi",
  platforms: [
    .macOS("26.0")
  ],
  products: [
    .library(name: "Anansi", targets: ["Anansi"]),
    .executable(name: "anansi-chat", targets: ["AnansiChat"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/swift-server/async-http-client.git",
      from: "1.25.1"),
    .package(
      url: "git@github.com:apple/swift-http-types.git",
      from: "1.3.1"),
    .package(
      url: "https://github.com/apple/swift-configuration", from: "0.2.0"),
    .package(url: "https://github.com/apple/swift-nio.git", from: "2.8.8"),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.2.1"),
    .package(url: "https://github.com/zaneenders/VirtualTerminal.git", branch: "macos-26"),
  ],
  targets: [
    .target(
      name: "Anansi",
      dependencies: [
        .product(name: "HTTPTypes", package: "swift-http-types"),
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "Subprocess", package: "swift-subprocess"),
        .product(name: "_NIOFileSystem", package: "swift-nio"),
      ]
    ),
    .executableTarget(
      name: "AnansiChat",
      dependencies: [
        "Anansi",
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "_NIOFileSystemFoundationCompat", package: "swift-nio"),
        .product(name: "_NIOFileSystem", package: "swift-nio"),
        .product(name: "Configuration", package: "swift-configuration"),
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "VirtualTerminal", package: "VirtualTerminal"),
      ]),
    .testTarget(
      name: "AnansiTests",
      dependencies: [
        "Anansi",
        .product(name: "NIOCore", package: "swift-nio"),
        .product(name: "_NIOFileSystemFoundationCompat", package: "swift-nio"),
        .product(name: "_NIOFileSystem", package: "swift-nio"),
        .product(name: "Configuration", package: "swift-configuration"),
        .product(name: "AsyncHTTPClient", package: "async-http-client"),
      ]),
  ]
)
