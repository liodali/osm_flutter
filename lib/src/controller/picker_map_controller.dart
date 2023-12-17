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

  ValueListenable<String> get searchableText => _searchableText;

  PickerMapController({
    UserTrackingOption? initMapWithUserPosition,
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
    await osmBaseController.goToPosition(p);
  }

  Future<void> advancedPositionPicker() async {
   
  }

  /// select current position and finish advanced picker
  Future<GeoPoint> selectAdvancedPositionPicker() async {
    throw Exception();
  }

  /// get current position
  Future<GeoPoint> getCurrentPositionAdvancedPositionPicker() async {
    throw Exception();
  }

  /// cancel advanced picker
  Future<void> cancelAdvancedPositionPicker() async {}

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void init() {
    super.init();
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
