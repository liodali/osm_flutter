import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/common/osm_option.dart';

import 'package:flutter_osm_plugin/src/controller/map_controller.dart';
import 'package:flutter_osm_plugin/src/osm_flutter.dart';

typedef PickerMarkerBuilder = Widget Function(BuildContext, bool);

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
  PickerMarkerBuilder? pickMarkerWidget,
  String? title,
  TextStyle? titleStyle,
  String? textConfirmPicker,
  String? textCancelPicker,
  EdgeInsets contentPadding = EdgeInsets.zero,
  double radius = 0.0,
  GeoPoint? initPosition,
  ZoomOption zoomOption = const ZoomOption(),
  bool isDismissible = false,
  UserTrackingOption? initCurrentUserPosition,
}) async {
  assert(title == null || titleWidget == null);
  assert(((initCurrentUserPosition != null) && initPosition == null) ||
      ((initCurrentUserPosition == null) && initPosition != null));
  final MapController controller = MapController(
    initMapWithUserPosition: initCurrentUserPosition,
    initPosition: initPosition,
  );
  GeoPoint? center = null;
  GeoPoint? old = null;
  GeoPoint? point = await showDialog(
    context: context,
    builder: (ctx) {
      return PopScope(
        canPop: isDismissible,
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
              child: StatefulBuilder(
                builder: (context, setState) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: OSMFlutter(
                          controller: controller,
                          onMapMoved: (regsion) {
                            setState(
                              () {
                                old = center;
                                center = regsion.center;
                              },
                            );
                          },
                          osmOption: OSMOption(
                            zoomOption: zoomOption,
                            isPicker: true,
                          ),
                        ),
                      ),
                      Positioned(
                        child: pickMarkerWidget != null
                            ? pickMarkerWidget(
                                context,
                                center != null && old != null
                                    ? center!.isEqual(old!)
                                    : center != null && old == null
                                        ? true
                                        : false)
                            : AnimatedCenterMarker(
                                center: center,
                              ),
                      )
                    ],
                  );
                },
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
                  final center = await controller.centerMap;
                  Navigator.pop(ctx, center);
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

class AnimatedCenterMarker extends StatefulWidget {
  final GeoPoint? center;
  const AnimatedCenterMarker({
    super.key,
    this.center,
  });
  @override
  State<StatefulWidget> createState() => _AnimatedCenterMarker();
}

class _AnimatedCenterMarker extends State<AnimatedCenterMarker> {
  late GeoPoint? _center = widget.center;
  bool isMoving = false;
  late Timer? timer = null;

  Timer createTimer() => Timer(Duration(seconds: 2), () {
        setState(() {
          isMoving = false;
        });
      });
  @override
  void didUpdateWidget(covariant AnimatedCenterMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {
      if (widget.center != null &&
          _center != null &&
          _center! != widget.center!) {
        isMoving = true;
        timer?.cancel();
        timer = createTimer();
      } else if (widget.center != null && _center == null) {
        isMoving = true;
        timer?.cancel();
        timer = createTimer();
      } else {
        isMoving = false;
        timer?.cancel();
      }
      _center = widget.center;
      debugPrint("isMoving: $isMoving");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            width: 5,
            height: 5,
            /* child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),*/
          ),
        ),
        AnimatedPositioned(
          top: 0,
          bottom: isMoving ? 42 : 26,
          left: 0,
          right: 0,
          duration: Duration(milliseconds: 300),
          child: Icon(
            Icons.location_on_rounded,
            size: 32,
            color: Colors.red,
          ),
        ),
      ],
    );
  }
}
