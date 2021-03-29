import 'dart:async';

import 'package:flutter/material.dart';

import '../types/geo_point.dart';
import 'base_map_controller.dart';

class PickerMapController extends BaseMapController {
  late ValueNotifier<String> _searchableText = ValueNotifier("");

  ValueNotifier<String> get searchableText => _searchableText;

  PickerMapController({
    bool initMapWithUserPosition = true,
    GeoPoint? initPosition,
  }) : super(
          initMapWithUserPosition: initMapWithUserPosition,
          initPosition: initPosition,
        );

  void setSearchableText(String value) {
    _searchableText.value = value;
  }

  ///animate  to specific position with out add marker into the map
  ///
  /// [p] : (GeoPoint) position that will be go to map
  Future<void> goToLocation(GeoPoint p) async {
    await osmController.goToPosition(p);
  }

  Future<void> advancedPositionPicker() async {
    await osmController.advancedPositionPicker();
  }

  /// select current position and finish advanced picker
  Future<GeoPoint> selectAdvancedPositionPicker() async {
    return await osmController.selectAdvancedPositionPicker();
  }

  /// get current position
  Future<GeoPoint> getCurrentPositionAdvancedPositionPicker() async {
    return await osmController.getCurrentPositionAdvancedPositionPicker();
  }

  /// cancel advanced picker
  Future<void> cancelAdvancedPositionPicker() async {
    return await osmController.cancelAdvancedPositionPicker();
  }
}
