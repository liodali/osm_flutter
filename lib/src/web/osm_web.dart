library osm_web;


import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_plugin/src/channel/osm_method_channel.dart';
import 'package:flutter_osm_plugin/src/interface_osm/osm_interface.dart';
import 'package:flutter_osm_plugin/src/types/geo_point.dart';
import 'package:flutter_osm_plugin/src/types/road.dart';
import 'package:flutter_osm_plugin/src/types/shape_osm.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'web_platform.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;
import 'package:js/js.dart' as js;
import 'dart:ui' as ui;
import './interop/osm_interop.dart';

part './flutter_osm_web.dart' ;
part '../controller/web_osm_controller.dart';
