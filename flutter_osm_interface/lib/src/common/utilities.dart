import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../types/types.dart';
import 'package:location/location.dart';
import 'dart:ui' as ui;

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

extension ExtLocationData on LocationData {
  GeoPoint toGeoPoint() {
    return GeoPoint(
        longitude: this.longitude ?? 0.0, latitude: this.latitude ?? 0.0);
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

Future<Uint8List> capturePng(GlobalKey globalKey) async {
  RenderRepaintBoundary boundary =
      globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  ui.Image image = await boundary.toImage();
  ByteData byteData =
      (await (image.toByteData(format: ui.ImageByteFormat.png)))!;
  Uint8List pngBytes = byteData.buffer.asUint8List();
  return pngBytes;
}
