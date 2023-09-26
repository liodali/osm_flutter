import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:routing_client_dart/routing_client_dart.dart';

import 'package:flutter_osm_web/src/interop/models/bounding_box_js.dart';
import 'package:flutter_osm_web/src/interop/models/geo_point_js.dart';

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

extension ExtSize on Size? {
  SizeJs toSizeJS() {
    return SizeJs(
      width: this?.width ?? 32,
      height: this?.height ?? 32,
    );
  }
}

extension ExtGlobelKey on GlobalKey<State<StatefulWidget>> {
  SizeJs toSizeJS() {
    final size = currentContext?.size;
    return size.toSizeJS();
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

extension ExtAnchor on IconAnchor {
  
  IconAnchorJS get toAnchorJS =>IconAnchorJS(
      x:  anchor.value.$1,
      y: anchor.value.$2,
      offset: offset != null
          ? IconOffsetAnchorJS(
              x: offset!.x,
              y: offset!.y,
            )
          : null,
    );
}
