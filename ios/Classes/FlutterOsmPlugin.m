#import "FlutterOsmPlugin.h"
#if __has_include(<flutter_osm_plugin/flutter_osm_plugin-Swift.h>)
#import <flutter_osm_plugin/flutter_osm_plugin-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_osm_plugin-Swift.h"
#endif

@implementation FlutterOsmPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterOsmPlugin registerWithRegistrar:registrar];
}
@end
