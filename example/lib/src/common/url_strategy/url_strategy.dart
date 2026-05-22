import 'package:flutter_osm_plugin_example/src/common/url_strategy/url_sub_web.dart'
    if (dart.library.io) 'package:flutter_osm_plugin_example/src/common/url_strategy/url_sub_io.dart'
    if (dart.library.js_interop) 'package:flutter_osm_plugin_example/src/common/url_strategy/url_sub_web.dart';

void usePathUrlStrategy() => urlStrategy();
