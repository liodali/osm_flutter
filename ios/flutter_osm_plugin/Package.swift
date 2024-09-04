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
    .iOS("13.0")
  ],
  products: [
    .library(name: "image-flutter_osm_plugin-ios", targets: ["flutter_osm_plugin"])
  ],
  dependencies: [
    .package(url:"https://github.com/liodali/OSMMapCoreIOSFramework.git",from: "0.7.4")
  ],
  targets: [
    .target(
      name: "flutter_osm_plugin",
      path: "Sources/flutter_osm_plugin",
      publicHeadersPath: "Sources/flutter_osm_plugin/",
      dependencies: [],
      resources: [
        //.process("Resources")
      ]
    ),
  ]
)
