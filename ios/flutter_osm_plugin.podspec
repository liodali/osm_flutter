#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_osm_plugin.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_osm_plugin'
  s.version          = '0.0.1'
  s.summary          = 'OSM plugin for flutter apps  Android,iOS,web '
  s.description      = <<-DESC
  OSM plugin for flutter apps  Android,iOS,web
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.resources = ['Assets/**.json']
  s.dependency 'Flutter'
  #s.dependency 'Tangram-es'
  s.dependency 'Alamofire'
  s.dependency 'Polyline'
  s.dependency 'Yams'
  s.dependency 'OSMFlutterFramework'
  #s.preserve_paths = 'Frameworks/OSMFlutterFramework.xcframework'
  #s.xcconfig = { 'OTHER_LDFLAGS' => '-framework OSMFlutterFramework' }
  #s.vendored_frameworks = 'OSMFlutterFramework.xcframework'
  #s.source = { :git => 'https://github.com/liodali/OSMMapCoreIOSFramework.git', :tag => '0.0.1' }

  #s.vendored_frameworks = 'Frameworks/OSMFlutterFramework.xcframework'
  s.platform = :ios, '13.0'
  #s.xcconfig = { 'OTHER_LDFLAGS' => '-framework OSMFlutterFramework' }
  #s.preserve_paths = 'OSMFlutterFramework.xcframework/**/*'
  #s.dependency 'OSMFlutterFramework'


  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
