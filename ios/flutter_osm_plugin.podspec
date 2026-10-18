#
# DEPRECATED — CocoaPods support is frozen and will NOT be updated anymore.
#
# OSMFlutterFramework suspended CocoaPods distribution with 0.9.0
# (MapCore 4.0.0), so this podspec can only ever resolve the legacy 0.8.x
# engine (maps-core 3.7.x era). It is kept solely so existing CocoaPods-based
# apps keep building; it receives no further maintenance.
#
# The plugin is Swift Package Manager (SPM) only going forward:
# the native iOS integration lives in ios/flutter_osm_plugin/Package.swift.
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_osm_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_osm_plugin'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_osm_plugin/Sources/flutter_osm_plugin/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.1'
  s.resources = ['Assets/**.json']
  s.dependency 'Flutter'
  s.dependency 'Alamofire'
  s.dependency 'Polyline'
  s.dependency 'Yams'
  # DEPRECATED: intentionally unpinned — CocoaPods resolves at most the legacy
  # 0.8.x line (0.9.0+ ships SPM-only). Do not update this podspec anymore.
  s.dependency 'OSMFlutterFramework'
  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_osm_plugin_privacy' => ['flutter_osm_plugin/Sources/flutter_osm_plugin/PrivacyInfo.xcprivacy']}
end
