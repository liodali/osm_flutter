import 'package:flutter/cupertino.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

mixin OSMMixinObserver {
  Future<void> mapIsReady(bool isReady);

  @mustCallSuper
  Future<void> mapRestored() async {}

  @mustCallSuper
  void onSingleTap(GeoPoint position) {}

  @mustCallSuper
  void onLongTap(GeoPoint position) {}

  @mustCallSuper
  void onRegionChanged(Region region) {}

  @mustCallSuper
  void onRoadTap(RoadInfo road) {}

  @mustCallSuper
  void onLocationChanged(UserLocation userLocation) {}
}
