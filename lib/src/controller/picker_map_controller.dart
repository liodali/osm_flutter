import 'package:flutter/foundation.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

/// [PickerMapController]
///
/// this controller for custom picker location widget
/// you will cancel/get/finish advanced picker
/// you can also draw road,change current location
/// get also current searchable text
class PickerMapController extends BaseMapController {
  late ValueNotifier<String> _searchableText = ValueNotifier("");
  late ValueNotifier<bool> _isMovingNotifier = ValueNotifier(false);

  ValueListenable<String> get searchableText => _searchableText;
  ValueListenable<bool> get isMapMovingNotifier => _isMovingNotifier;

  PickerMapController({
    UserTrackingOption? initMapWithUserPosition,
    GeoPoint? initPosition,
  }) : super(
          initMapWithUserPosition: initMapWithUserPosition,
          initPosition: initPosition,
        );

  void setSearchableText(String text) {
    _searchableText.value = text;
  }
  void setMapMoving(bool isMoving) {
    _isMovingNotifier.value = isMoving;
  }

  ///animate  to specific position with out add marker into the map
  ///
  /// [p] : (GeoPoint) position that will be go to map
  Future<void> goToLocation(GeoPoint p) async {
    await osmBaseController.goToPosition(p);
  }

  /// isMapMoving
  ///
  /// this method is to trieve is the map currently moving or not
  bool isMapMoving() => _isMovingNotifier.value;

  /// [selectAdvancedPositionPicker]
  ///
  /// select current position and finish advanced picker
  Future<GeoPoint> selectAdvancedPositionPicker() {
    return osmBaseController.getMapCenter();
  }

  // void init() {
  //   //setBaseOSMController(controller);
  //   Future.delayed(Duration(milliseconds: 1250), () async {
  //     await osmBaseController.initMap(
  //       initPosition: initPosition,
  //       initWithUserPosition: initMapWithUserPosition,
  //     );
  //   });
  // }
}