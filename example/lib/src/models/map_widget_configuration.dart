import 'package:flutter/widgets.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart'
    show MapController, GeoPoint;

typedef MoreActionConfig = ({
  MapController controller,
  ValueNotifier<bool> trackingNotifier,
  ValueNotifier<GeoPoint?> userLocationNotifier,
  ValueNotifier<IconData> userLocationIcon,
  ValueNotifier<List<GeoPoint>> geos,
});
