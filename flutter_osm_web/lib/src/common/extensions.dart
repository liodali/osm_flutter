import 'dart:math';

import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:routing_client_dart/routing_client_dart.dart';

import '../interop/models/bounding_box_js.dart';
import '../interop/models/geo_point_js.dart';

extension ExtGeoPoint on GeoPoint {
  GeoPointJs toGeoJS() {
    return GeoPointJs(
      lon: longitude,
      lat: latitude,
    );
  }

  LngLat toLngLat() {
    return LngLat(
      lng: longitude,
      lat: latitude,
    );
  }
}

extension ExtGeoPointWithOrientation on GeoPointWithOrientation {
  GeoPointWithOrientationJs toGeoJS() {
    return GeoPointWithOrientationJs(
      lon: longitude,
      lat: latitude,
      angle: angle * 180 / pi,
    );
  }
}

extension ExtLngLat on LngLat {
  GeoPointJs toGeoJS() {
    return GeoPointJs(
      lon: lng,
      lat: lat,
    );
  }

  GeoPoint toGeoPoint() {
    return GeoPoint(
      longitude: lng,
      latitude: lat,
    );
  }
}

extension ExtListLngLat on List<LngLat> {
  List<GeoPointJs> mapToListGeoJS() {
    return this.map((e) => e.toGeoJS()).toList();
  }

  List<GeoPoint> mapToListGeoPoints() {
    return this.map((e) => e.toGeoPoint()).toList();
  }
}

extension ExtBoundingBox on BoundingBox {
  BoundingBoxJs toBoundsJS() {
    return BoundingBoxJs(
      south: south,
      north: north,
      east: east,
      west: west,
    );
  }
}

extension ExtListGeoPoints on List<GeoPoint> {
  List<LngLat> toLngLatList() {
    return map((e) => e.toLngLat()).toList();
  }

  List<GeoPointJs> toListGeoPointJs() {
    return this.map((e) => e.toGeoJS()).toList();
  }
}
