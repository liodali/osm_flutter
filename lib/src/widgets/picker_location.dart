import 'dart:async';
import 'package:flutter/widgets.dart';
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
/// The dialog is design-system neutral. Labels default to English ('OK' and
/// 'Cancel'); pass translated labels for other locales.
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
  assert(
    ((initCurrentUserPosition != null) && initPosition == null) ||
        ((initCurrentUserPosition == null) && initPosition != null),
  );
  final MapController controller = MapController(
    initMapWithUserPosition: initCurrentUserPosition,
    initPosition: initPosition,
  );
  GeoPoint? center;
  GeoPoint? old;
  // Labels are caller-localizable; no MaterialLocalizations are required.
  GeoPoint? point = await showGeneralDialog<GeoPoint>(
    barrierDismissible: isDismissible,
    barrierLabel: textCancelPicker ?? 'Cancel',
    context: context,
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return PopScope(
        canPop: isDismissible,
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(radius),
              ),
              clipBehavior: Clip.antiAlias,
              child: DefaultTextStyle(
                style: const TextStyle(color: Color(0xFF000000), fontSize: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null || titleWidget != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child:
                            title != null
                                ? Text(title, style: titleStyle)
                                : titleWidget,
                      ),
                    Padding(
                      padding: contentPadding,
                      child: SizedBox(
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
                                      setState(() {
                                        old = center;
                                        center = regsion.center;
                                      });
                                    },
                                    osmOption: OSMOption(
                                      zoomOption: zoomOption,
                                      isPicker: true,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  child:
                                      pickMarkerWidget != null
                                          ? pickMarkerWidget(
                                            context,
                                            center != null && old != null
                                                ? center!.isEqual(old!)
                                                : center != null && old == null
                                                ? true
                                                : false,
                                          )
                                          : AnimatedCenterMarker(
                                            center: center,
                                          ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        children: [
                          _PickerButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(textCancelPicker ?? 'Cancel'),
                          ),
                          _PickerButton(
                            onPressed: () async {
                              final center = await controller.centerMap;
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx, center);
                            },
                            child: Text(textConfirmPicker ?? 'OK'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  return point;
}

class _PickerButton extends StatefulWidget {
  const _PickerButton({required this.onPressed, required this.child,});

  final VoidCallback onPressed;
  final Widget child;

  @override
  State<_PickerButton> createState() => _PickerButtonState();
}

class _PickerButtonState extends State<_PickerButton> {
  bool _showFocus = false;

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    mouseCursor: SystemMouseCursors.click,
    onShowFocusHighlight: (show) => setState(() => _showFocus = show),
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onPressed();
          return null;
        },
      ),
    },
    child: Semantics(
      button: true,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  _showFocus
                      ? const Color(0xFF2196F3)
                      : const Color(0x00000000),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}

class AnimatedCenterMarker extends StatefulWidget {
  final GeoPoint? center;
  const AnimatedCenterMarker({super.key, this.center});
  @override
  State<StatefulWidget> createState() => _AnimatedCenterMarker();
}

class _AnimatedCenterMarker extends State<AnimatedCenterMarker> {
  late GeoPoint? _center = widget.center;
  bool isMoving = false;
  Timer? timer;

  Timer createTimer() => Timer(const Duration(seconds: 2), () {
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
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF000000),
              shape: BoxShape.circle,
            ),
            width: 5,
            height: 5,
          ),
        ),
        AnimatedPositioned(
          top: 0,
          bottom: isMoving ? 42 : 26,
          left: 0,
          right: 0,
          duration: const Duration(milliseconds: 300),
          child: Center(
            child: Image.asset(
              'packages/flutter_osm_plugin/assets/default_pin.png',
              width: 32,
              height: 32,
            ),
          ),
        ),
      ],
    );
  }
}
