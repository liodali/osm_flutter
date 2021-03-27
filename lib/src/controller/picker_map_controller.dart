import '../types/geo_point.dart';
import 'base_map_controller.dart';

class PickerMapController extends BaseMapController {
  PickerMapController({
    bool initMapWithUserPosition = true,
    GeoPoint? initPosition,
  })  : assert(
          initMapWithUserPosition || initPosition != null,
        ),
        super(
          initMapWithUserPosition: initMapWithUserPosition,
          initPosition: initPosition,
        );

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
