// swift-tools-version:5.0

///  Files
///  Copyright (c) John Sundell 2017
///  Licensed under the MIT license. See LICENSE file.

import PackageDescription

let package = Package(
  name: "Files",
  products: [
    .library(name: "Files", targets: ["Files"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.4"),
    .package(url: "https://github.com/airbnb/swift", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "Files",
      dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser")],
      path: "Sources"),
    .testTarget(
      name: "FilesTests",
      dependencies: ["Files"]),
  ])
