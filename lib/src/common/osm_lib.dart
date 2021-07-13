library osm_flutter;

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin/src/channel/osm_method_channel.dart';
import 'package:flutter_osm_plugin/src/types/geo_point.dart';
import 'package:flutter_osm_plugin/src/types/road.dart';
import 'package:flutter_osm_plugin/src/types/shape_osm.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:location/location.dart';

import '../../../flutter_osm_plugin.dart';
import '../../flutter_osm_plugin.dart';
import '../controller/osm_controller.dart';
import '../types/geo_point.dart';
import '../types/types.dart';
import '../web/interop/osm_interop.dart' as interop show addPosition,locateMe;
import '../web/interop/models/geo_point_js.dart'  show GeoPointJs;

import '../web/web_platform.dart';
import '../widgets/copyright_osm_widget.dart';

part '../controller/base_map_controller.dart';

part '../controller/map_controller.dart';

part '../controller/picker_map_controller.dart';

part '../controller/web_osm_controller.dart';

part '../osm_flutter.dart';

part '../web/flutter_osm_web.dart';

part '../web/widget/osm_web_widget.dart';

part '../widgets/custom_picker_location.dart';
