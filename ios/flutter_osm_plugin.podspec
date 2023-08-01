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
  s.dependency 'Tangram-es'
  s.dependency 'Alamofire'
  s.dependency 'Polyline'
  s.dependency 'Yams'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'
end
