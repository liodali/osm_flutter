import 'package:flutter/material.dart';

import '../../flutter_osm_plugin.dart';

/// pickerLocation : picker to select specific position
///
/// [title] : (widget) title widget of dialog
Future<GeoPoint?> pickerLocation({
  required BuildContext context,
  required Widget title,
  Widget? confirmPicker,
  GeoPoint? initPosition,
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
      return WillPopScope(
        onWillPop: () async {
          return isDismissible;
        },
        child: Column(
          children: [
            title,
            Expanded(
              child: Stack(
                children: [
                  OSMFlutter(
                    controller: controller,
                    isPicker: true,
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: GestureDetector(
                      onTap: () async {
                        final p =
                            await controller.selectAdvancedPositionPicker();
                        Navigator.pop(ctx, p);
                      },
                      child: AbsorbPointer(
                        absorbing: true,
                        child: confirmPicker ??
                            FloatingActionButton(
                              onPressed: () {},
                              child: Icon(Icons.location_on),
                            ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  return point;
}
