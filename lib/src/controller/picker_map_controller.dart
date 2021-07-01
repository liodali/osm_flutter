part of osm_flutter;



/// controller for custom picker location widget
/// you will cancel/get/finish advanced picker
/// you can also draw road,change current location
/// get also current searchable text
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
    await _osmController.goToPosition(p);
  }

  Future<void> advancedPositionPicker() async {
    await _osmController.advancedPositionPicker();
  }

  /// select current position and finish advanced picker
  Future<GeoPoint> selectAdvancedPositionPicker() async {
    return await _osmController.selectAdvancedPositionPicker();
  }

  /// get current position
  Future<GeoPoint> getCurrentPositionAdvancedPositionPicker() async {
    return await _osmController.getCurrentPositionAdvancedPositionPicker();
  }

  /// cancel advanced picker
  Future<void> cancelAdvancedPositionPicker() async {
    return await _osmController.cancelAdvancedPositionPicker();
  }
}
