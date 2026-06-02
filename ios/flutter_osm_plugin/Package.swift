// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Package.swift
//  flutter_osm_plugin
//
//  Created by Dali Hamza on 31.08.24.
//

import PackageDescription

let package = Package(
  name: "flutter_osm_plugin",
  platforms: [
    .iOS("15.6")
  ],
  products: [
    .library(name: "flutter-osm-plugin-ios", targets: ["flutter_osm_plugin"])
  ],
  dependencies: [
    .package(url:"https://github.com/liodali/OSMMapCoreIOSFramework.git",from: "0.7.4"),
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "flutter_osm_plugin",
      path: "Sources/flutter_osm_plugin",
      publicHeadersPath: "Sources/flutter_osm_plugin/",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ],
      resources: [
        //.process("Resources")
      ]
    ),
  ]
)
