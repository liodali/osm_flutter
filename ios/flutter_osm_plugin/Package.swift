// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_osm_plugin",
    platforms: [
        .iOS("15.6")
    ],
    products: [
        .library(name: "flutter-osm-plugin", targets: ["flutter_osm_plugin"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // .package(name: "OSMMapCoreIOSFramework", path: "../OSMMapCoreIOSFramework"),
        // .package(url: "https://github.com/UbiqueInnovation/djinni.git", exact: "1.0.9"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.11.0")),
        .package(url: "https://github.com/raphaelmor/Polyline.git", from: "5.1.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.2"),
        .package(
            url: "https://github.com/liodali/OSMMapCoreIOSFramework.git",
            revision: "b78896c390aa88abd24fc3116de4aeef74196aba"),
        //exact: "0.8.6"),
        // .package(url: "https://github.com/openmobilemaps/maps-core.git", from: "3.7.1"),
        // .package(url: "https://github.com/raphaelmor/Polyline.git", from: "5.1.0")

    ],
    targets: [
        .target(
            name: "flutter_osm_plugin",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "OSMFlutterFramework", package: "OSMMapCoreIOSFramework"),
                .product(name: "Polyline", package: "Polyline"),
                .product(name: "Alamofire", package: "Alamofire"),
                // .product(name: "Yams", package: "Yams"),
                // .product(name: "MapCore", package: "MapCore")
            ],
            resources: [
                // If your plugin requires a privacy manifest, for example if it uses any required
                // reason APIs, update the PrivacyInfo.xcprivacy file to describe your plugin's
                // privacy impact, and then uncomment these lines. For more information, see
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),

                // If you have other resources that need to be bundled with your plugin, refer to
                // the following instructions to add them:
                // https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-strict-concurrency=minimal", "-enable-experimental-feature",
                    "AccessLevelOnImport",
                ])
            ]
        )
    ]
)
