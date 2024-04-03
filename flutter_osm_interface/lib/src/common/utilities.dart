import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

import 'package:flutter_osm_interface/src/types/types.dart';

typedef OnGeoPointClicked = void Function(GeoPoint);
typedef OnLocationChanged = void Function(GeoPoint);
typedef OnMapMoved = void Function(Region);

const iosSizeIcon = [48.0, 48.0];
const earthRadiusMeters = 6378137;
const deg2rad = pi / 180.0;
const rad2deg = 180.0 / pi;

@visibleForTesting
bool isEqual1eX(double value) {
  final log10Value = log(value) / ln10;
  final exponent = log10Value.toInt();
  final calcularedV = double.parse(
      pow(10, log10Value.round()).toStringAsFixed(log10Value.round().abs()));
  return value == calcularedV && (exponent.abs() >= 2 && exponent.abs() <= 8);
}

extension ExtGeoPoint on GeoPoint {
  List<num> toListNum() {
    return [
      this.latitude,
      this.longitude,
    ];
  }

  bool isEqual(GeoPoint location, {double precision = 1e6}) {
    assert(isEqual1eX(precision), "precision should be between 1e-2,1e-8");
    final exponent = log(precision) ~/ log10e;
    final nPrecision = exponent.isNegative ? precision : 1 / precision;
    return (latitude - location.latitude).abs() <= nPrecision &&
        (longitude - location.longitude).abs() <= nPrecision;
  }
}

extension ExtListGeoPoint on List<GeoPoint> {
  Future<String> encodedToString() async {
    final List<GeoPoint> listGeos = this;
    return compute((List<GeoPoint> geoPoints) async {
      final coordinates = geoPoints.map((e) => e.toListNum()).toList();
      return encodePolyline(coordinates);
    }, listGeos);
  }
}

extension TransformEncodedPolyLineToListGeo on String {
  Future<List<GeoPoint>> toListGeo() async {
    final String polylineEncoded = this;
    try {
      return await compute(
        (String encoded) {
          final listPoints = decodePolyline(encoded, accuracyExponent: 5);
          return listPoints
              .map((e) => GeoPoint(
                  latitude: e.first.toDouble(), longitude: e.last.toDouble()))
              .toList();
        },
        polylineEncoded,
      );
    } catch (e) {
      return [];
    }
  }
}

extension ColorMap on Color {
  Color dark() {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - .3).clamp(0.0, 1.0));

    return hslDark.toColor();
  }

  Map<String, dynamic> toMapPlatform(String key) {
    if (Platform.isIOS) {
      return toHexMap(key);
    }
    return toMap(key);
  }

  dynamic toPlatform() {
    if (kIsWeb) {
      return toHexColorWeb();
    }
    if (Platform.isIOS) {
      return toHexColor();
    }
    return [
      this.red,
      this.blue,
      this.green,
    ];
  }

  List<int> toARGBList() => [
        red,
        blue,
        green,
        alpha,
      ];

  Map<String, List<int>> toMap(String key) {
    return {
      "$key": [
        this.red,
        this.blue,
        this.green,
      ]
    };
  }

  List<int> toList() {
    return [
      this.red,
      this.blue,
      this.green,
    ];
  }

  Map<String, String> toHexMap(String key) {
    return {"$key": "#${this.value.toRadixString(16)}"};
  }

  String toHexColor() {
    if (kIsWeb) {
      return toHexColorWeb();
    }
    return "#${this.value.toRadixString(16)}";
  }

  String toHexColorWeb() {
    return "#${this.value.toRadixString(16)}".replaceFirst("ff", "");
  }
}

extension Uint8ListConvert on Uint8List {
  String convertToString() {
    return base64.encode(this);
  }
}

extension ListMultiRoadConf on List<MultiRoadConfiguration> {
  List<Map<String, dynamic>> toListMap({
    MultiRoadOption commonRoadOption = const MultiRoadOption(
      roadColor: Colors.green,
      roadType: RoadType.car,
    ),
  }) {
    final List<Map<String, dynamic>> listMap = [];

    for (MultiRoadConfiguration roadConf in this) {
      final map = <String, dynamic>{};

      map["wayPoints"] = [
        roadConf.startPoint.toMap(),
        roadConf.destinationPoint.toMap(),
      ];
      map["roadType"] = roadConf.roadOptionConfiguration?.roadType.toString() ??
          commonRoadOption.roadType.toString();
      final color = roadConf.roadOptionConfiguration?.roadColor ??
          commonRoadOption.roadColor;
      if (Platform.isIOS) {
        map.addAll(color.toHexMap("roadColor"));

        map["roadWidth"] =
            "${roadConf.roadOptionConfiguration?.roadWidth ?? commonRoadOption.roadWidth}px";
      } else {
        map.addAll(color.toMap("roadColor"));

        map["roadWidth"] = roadConf.roadOptionConfiguration?.roadWidth ??
            commonRoadOption.roadWidth;
      }

      map["middlePoints"] =
          roadConf.intersectPoints.map((e) => e.toMap()).toList();
      listMap.add(map);
    }
    return listMap;
  }
}

Future<Uint8List> capturePng(GlobalKey globalKey) async {
  RenderRepaintBoundary boundary =
      globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  ui.Image image = await boundary.toImage();
  ByteData byteData =
      (await (image.toByteData(format: ui.ImageByteFormat.png)))!;
  Uint8List pngBytes = byteData.buffer.asUint8List();
  return pngBytes;
}

extension ExtTileUrls on TileURLs {
  dynamic toMapPlatform() {
    if (Platform.isAndroid) {
      return toMapAndroid();
    }
    if (Platform.isIOS) {
      return toMapiOS();
    }
    if (kIsWeb) {
      return toWeb();
    }
    throw UnsupportedError("platform not supported yet");
  }
}

extension ExtString on String {
  List<GeoPoint> stringToGeoPoints() {
    return decodePolyline(
      this,
    )
        .map((e) => GeoPoint(
              latitude: e.first.toDouble(),
              longitude: e.last.toDouble(),
            ))
        .toList();
  }
}

/// [geoPointAsRect]
///
/// this method will calculate the bounds from [center] using [lengthInMeters] and [widthInMeters]
/// this method usefull to get Rect or bounds
///
/// return List of [GeoPoint]
List<GeoPoint> geoPointAsRect({
  required GeoPoint center,
  required double lengthInMeters,
  required double widthInMeters,
}) {
  final List<GeoPoint> bounds = <GeoPoint>[];
  GeoPoint east = center.destinationPoint(
    distanceInMeters: lengthInMeters * 0.5,
    bearingInDegrees: 90,
  );
  GeoPoint south = center.destinationPoint(
    distanceInMeters: widthInMeters * 0.5,
    bearingInDegrees: 180,
  );
  double westLon = center.longitude * 2 - east.longitude;
  double northLat = center.latitude * 2 - south.latitude;
  bounds.add(GeoPoint(latitude: south.latitude, longitude: east.longitude));
  bounds.add(GeoPoint(latitude: south.latitude, longitude: westLon));
  bounds.add(GeoPoint(latitude: northLat, longitude: westLon));
  bounds.add(GeoPoint(latitude: northLat, longitude: east.longitude));
  return bounds;
}
