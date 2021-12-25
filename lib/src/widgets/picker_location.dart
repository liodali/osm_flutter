import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

import '../controller/map_controller.dart';
import '../osm_flutter.dart';

/// showSimplePickerLocation : picker to select specific position
///
/// [context] : (BuildContext) dialog context parent
///
/// [titleWidget] : (Widget) widget title  of the dialog
///
/// [title] : (String) text title widget of the dialog
///
/// [titleStyle] : (TextStyle) style text title widget of the dialog
///
/// [textConfirmPicker] : (String) text confirm button widget of the dialog
///
/// [textCancelPicker] : (String) text cancel button widget of the dialog
///
/// [radius] : (double) rounded radius of the dialog
///
/// [isDismissible] : (bool) to indicate if tapping out side of dialog will dismiss the dialog
///
/// [initCurrentUserPosition] : (GeoPoint) to indicate initialize position in the map
///
/// [initPosition] : (bool) to initialize the map  in user location
Future<GeoPoint?> showSimplePickerLocation({
  required BuildContext context,
  Widget? titleWidget,
  String? title,
  TextStyle? titleStyle,
  String? textConfirmPicker,
  String? textCancelPicker,
  EdgeInsets contentPadding = EdgeInsets.zero,
  double radius = 0.0,
  GeoPoint? initPosition,
  double stepZoom = 1,
  double initZoom = 2,
  double minZoomLevel = 2,
  double maxZoomLevel = 18,
  bool isDismissible = false,
  bool initCurrentUserPosition = true,
}) async {
  assert(title == null || titleWidget == null);
  assert((initCurrentUserPosition && initPosition == null) ||
      !initCurrentUserPosition && initPosition != null);
  final MapController controller = MapController(
    initMapWithUserPosition: initCurrentUserPosition,
    initPosition: initPosition,
  );

  GeoPoint? point = await showDialog(
    context: context,
    builder: (ctx) {
      return WillPopScope(
        onWillPop: () async {
          return isDismissible;
        },
        child: SizedBox(
          height: MediaQuery.of(context).size.height / 2.4,
          width: MediaQuery.of(context).size.height / 2,
          child: AlertDialog(
            title: title != null
                ? Text(
                    title,
                    style: titleStyle,
                  )
                : titleWidget,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(radius),
              ),
            ),
            contentPadding: contentPadding,
            content: SizedBox(
              height: MediaQuery.of(context).size.height / 2.5,
              width: MediaQuery.of(context).size.height / 2,
              child: OSMFlutter(
                controller: controller,
                isPicker: true,
                stepZoom: stepZoom,
                initZoom: initZoom,
                minZoomLevel: minZoomLevel,
                maxZoomLevel: maxZoomLevel,
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
                  final p = await controller
                      .getCurrentPositionAdvancedPositionPicker();
                  await controller.cancelAdvancedPositionPicker();
                  Navigator.pop(ctx, p);
                },
                child: Text(
                  textConfirmPicker ??
                      MaterialLocalizations.of(context).okButtonLabel,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  return point;
}
