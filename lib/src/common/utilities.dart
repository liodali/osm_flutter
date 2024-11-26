import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:routing_client_dart/routing_client_dart.dart';

const earthRadius = 6371e3; //metre

/// calculate square of sin : sin²
/// [x] : (num) number that you want to calculate it's sin²
double sqrtSin(num x) {
  return math.sin(x) * math.sin(x);
}

/// calculate square of cos : cos²
/// [x] : (num) number that you want to calculate it's cos²
double sqrtCos(num x) {
  return math.cos(x) * math.cos(x);
}

/// calculate multiplication of cos : cos x * cos y
/// [x] : (num) number of the first cos
/// [x] : (num) number of second cos
double sqrtCos2(num x, num y) {
  return math.cos(x) * math.cos(y);
}

/// calculate approximately distance between two geographique point using  haversine formula
/// fore more detail @link: https://www.movable-type.co.uk/scripts/latlong.html
/// return value in metres
/// [p1] : (GeoPoint) first point in road
/// [p2] : (GeoPoint) last point in road
Future<double> distance2point(GeoPoint p1, GeoPoint p2) async {
  final phi1 = p1.latitude * math.pi / 180; // φ, λ in radians
  final phi2 = p2.latitude * math.pi / 180;
  final deltaPhi = (p2.latitude - p1.latitude) * math.pi / 180;
  final deltaLambda = (p2.longitude - p1.longitude) * math.pi / 180;

  final double a =
      sqrtSin(deltaPhi / 2) + sqrtCos2(phi1, phi2) * sqrtSin(deltaLambda / 2);

  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return earthRadius * c; //metres
}

Future<List<SearchInfo>> addressSuggestion(String searchText,
    {int limitInformation = 5, String locale = ""}) async {
  Response response = await Dio().get(
    "https://photon.komoot.io/api/",
    queryParameters: {
      "q": searchText,
      "limit": limitInformation == 0 ? "" : "$limitInformation",
      "lang": locale
    },
  );
  final json = response.data;

  return (json["features"] as List)
      .map((d) => SearchInfo.fromPhotonAPI(d))
      .toList();
}

extension ExtGeoPoint2 on GeoPoint {
  LngLat toLngLat() {
    return LngLat(
      lng: longitude,
      lat: latitude,
    );
  }
}

extension ExtLatLng on LngLat {
  GeoPoint toGeoPoint() {
    return GeoPoint(
      longitude: lng,
      latitude: lat,
    );
  }
}

extension ExtListLatLng on List<LngLat> {

  List<GeoPoint> toGeoPointList() {
    return map((lngLat) => lngLat.toGeoPoint()).toList();
  }
}

extension ExtListGeoPoints on List<GeoPoint> {
  List<LngLat> toLngLatList() {
    return map((e) => e.toLngLat()).toList();
  }
}

extension ExtRoadInstruction on RoadInstruction {
  Instruction toInstruction() {
    return Instruction(
      distance: distance,
      duration: duration,
      instruction: instruction,
      geoPoint: location.toGeoPoint(),
    );
  }
}
