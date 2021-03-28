import 'package:flutter/material.dart';

import '../controller/picker_map_controller.dart';
import '../osm_flutter.dart';
import '../types/geo_point.dart';

class CustomPickerLocation extends StatefulWidget {
  final AppBar appBarPicker;
  final Widget? bottomWidgetPicker;
  final GeoPoint? initPosition;
  final bool initUserPosition;
  final PickerMapController controller;

  CustomPickerLocation({
    required this.appBarPicker,
    this.bottomWidgetPicker,
    this.initPosition,
    this.initUserPosition = true,
    Key? key,
  })  : assert(
          initUserPosition || initPosition != null,
        ),
        this.controller = PickerMapController(
          initPosition: initPosition,
          initMapWithUserPosition: initUserPosition,
        ),
        super(key: key);

  static PickerMapController of<T>(
    BuildContext context, {
    bool nullOk = false,
  }) {
    final _CustomPickerLocationState? result =
        context.findAncestorStateOfType<_CustomPickerLocationState>();
    if (nullOk || result != null) return result!.widget.controller;
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary(
          'CustomPickerLocation.of() called with a context that does not contain an MapController.'),
      ErrorDescription(
          'No CustomPickerLocation ancestor could be found starting from the context that was passed to CustomPickerLocation.of().'),
      context.describeElement('The context used was')
    ]);
  }

  @override
  _CustomPickerLocationState createState() => _CustomPickerLocationState();
}

class _CustomPickerLocationState extends State<CustomPickerLocation> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx){
        return Scaffold(
          appBar: widget.appBarPicker,
          body: Stack(
            children: [
              Positioned(
                top: 56,
                child: OSMFlutter(
                  controller: widget.controller,
                  isPicker: true,
                ),
              ),
              if (widget.bottomWidgetPicker != null) ...[
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Builder(builder: (ctx) {
                    return widget.bottomWidgetPicker!;
                  }),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
