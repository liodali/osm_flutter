import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

extension ColorMap on Color {
  Map<String, List<int>> toMap(String key) {
    return {
      "$key": [this.red, this.blue, this.green]
    };
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
    for (MultiRoadConfiguration roadConf in this) {
      final map = {};
      map["wayPoints"] = [
        roadConf.startPoint.toMap(),
        roadConf.destinationPoint.toMap(),
      ];
      map["roadType"] = roadConf.roadOptionConfiguration?.roadType ?? commonRoadOption.roadType;
      map["roadColor"] = roadConf.roadOptionConfiguration?.roadColor ?? commonRoadOption.roadColor;
      map["roadWidth"] = roadConf.roadOptionConfiguration?.roadWidth ?? commonRoadOption.roadWidth;
      map["middlePoints"] = roadConf.intersectPoints.map((e) => e.toMap()).toList();
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
