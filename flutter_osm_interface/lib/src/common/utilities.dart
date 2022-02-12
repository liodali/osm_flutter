import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

import '../types/types.dart';

typedef OnGeoPointClicked = void Function(GeoPoint);
typedef OnLocationChanged = void Function(GeoPoint);

extension ExtGeoPoint on GeoPoint {
  List<num> toListNum() {
    return [
      this.longitude,
      this.latitude,
    ];
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
      return await compute((String encoded) {
        final listPoints = decodePolyline(encoded);
        return listPoints
            .map((e) => GeoPoint(latitude: e.last.toDouble(), longitude: e.first.toDouble()))
            .toList();
      }, polylineEncoded);
    } catch (e) {
      return [];
    }
  }
}

extension ColorMap on Color {
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
    return "#${this.value.toRadixString(16)}";
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
    final defaultWidth = 5.0;

    for (MultiRoadConfiguration roadConf in this) {
      final map = <String, dynamic>{};
      map["wayPoints"] = [
        roadConf.startPoint.toMap(),
        roadConf.destinationPoint.toMap(),
      ];
      map["roadType"] = roadConf.roadOptionConfiguration?.roadType.toString() ??
          commonRoadOption.roadType.toString();
      final color = roadConf.roadOptionConfiguration?.roadColor ?? commonRoadOption.roadColor;
      if (Platform.isIOS) {
        if (color != null) {
          map.addAll(color.toHexMap("roadColor"));
        }
        map["roadWidth"] =
            "${roadConf.roadOptionConfiguration?.roadWidth ?? commonRoadOption.roadWidth ?? defaultWidth}px";
      } else {
        if (color != null) {
          map.addAll(color.toMap("roadColor"));
        }
        map["roadWidth"] = roadConf.roadOptionConfiguration?.roadWidth ??
            commonRoadOption.roadWidth ??
            defaultWidth;
      }

      map["middlePoints"] = roadConf.intersectPoints.map((e) => e.toMap()).toList();
      listMap.add(map);
    }
    return listMap;
  }
}

Future<Uint8List> capturePng(GlobalKey globalKey) async {
  RenderRepaintBoundary boundary =
      globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  ui.Image image = await boundary.toImage();
  ByteData byteData = (await (image.toByteData(format: ui.ImageByteFormat.png)))!;
  Uint8List pngBytes = byteData.buffer.asUint8List();
  return pngBytes;
}
