import 'package:flutter/material.dart';
import '../../flutter_osm_plugin.dart';
import '../controller/map_controller.dart';
import '../osm_flutter.dart';

/// showSimplePickerLocation : picker to select specific position
///
/// [context] : (BuildContext) dialog context parent
/// [title] : (String) text title widget of dialog
/// [textConfirmPicker] : (String) text confirm button widget of dialog
/// [textCancelPicker] : (String) text cancel button widget of dialog
/// [radius] : (double) rounded radius of the dialog
/// [isDismissible] : (bool) to indicate if tapping out side of dialog will dismiss the dialog
/// [initCurrentUserPosition] : (GeoPoint) to indicate initialize position in the map
/// [initPosition] : (bool) to initialize the map  in user location
Future<GeoPoint?> showSimplePickerLocation({
  required BuildContext context,
  required String title,
  String? textConfirmPicker,
  String? textCancelPicker,
  double radius = 0.0,
  GeoPoint? initPosition,
  double stepZoom = 1,
  double initZoom = 2,
  int minZoomLevel = 2,
  int maxZoomLevel = 18,
  bool isDismissible = false,
  bool initCurrentUserPosition = true,
}) async {
  assert((initCurrentUserPosition && initPosition == null) ||
      !initCurrentUserPosition && initPosition != null);
  final MapController controller = MapController(
    initMapWithUserPosition: initCurrentUserPosition,
    initPosition: initPosition,
  );
  GeoPoint? point = await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(radius),
          ),
        ),
        content: WillPopScope(
          onWillPop: () async {
            return isDismissible;
          },
          child: SizedBox(
            height: MediaQuery.of(context).size.height / 2.5,
            child: OSMFlutter(
              controller: controller,
              isPicker: true,
              stepZoom: stepZoom,
              initZoom: initZoom,
              minZoomLevel: minZoomLevel,
              maxZoomLevel: maxZoomLevel,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              textCancelPicker ??
                  MaterialLocalizations.of(context).cancelButtonLabel,
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final p =
                  await controller.getCurrentPositionAdvancedPositionPicker();
              await controller.cancelAdvancedPositionPicker();
              Navigator.pop(ctx, p);
            },
            child: Text(
              textConfirmPicker ??
                  MaterialLocalizations.of(context).okButtonLabel,
            ),
          ),
        ],
      );
    },
  );

  return point;
}
