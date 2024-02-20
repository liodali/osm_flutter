import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_plugin/src/common/osm_option.dart';

import 'package:flutter_osm_plugin/src/controller/picker_map_controller.dart';
import 'package:flutter_osm_plugin/src/osm_flutter.dart';
import 'package:flutter_osm_plugin/src/widgets/picker_location.dart';

class CustomPickerLocationConfig {
  final Widget? loadingWidget;
  final MarkerIcon? advancedMarkerPicker;
  final ZoomOption zoomOption;

  const CustomPickerLocationConfig({
    this.loadingWidget,
    this.advancedMarkerPicker,
    this.zoomOption = const ZoomOption(
      maxZoomLevel: 18,
      minZoomLevel: 2,
    ),
  });
}

/// CustomPickerLocation
///
/// used to create customizable search location widget using OSMFlutter : to pick location from address
///
/// [controller] : controller for custom picker location
///
/// [appBarPicker] : toolbar widget for CustomPickerLocation
///
/// [topWidgetPicker] :  widget above of osm flutter widget to show list of address suggestion
///
/// [bottomWidgetPicker] :  widget on bottom of screen and above the osm flutter widget to show another information or action widget for the picker
///
/// [bottomWidgetPicker] :  widget on bottom of screen and above the osm flutter widget to show another information or action widget for the picker
///
/// [pickerConfig]      : (CustomPickerLocationConfig) configure the inner OSMFlutter
class CustomPickerLocation extends StatefulWidget {
  final PickerMapController controller;
  final AppBar? appBarPicker;
  final Widget? topWidgetPicker;
  final Widget? bottomWidgetPicker;
  final CustomPickerLocationConfig pickerConfig;
  final Function(bool)? onMapReady;
  final bool showDefaultMarkerPickWidget;

  CustomPickerLocation({
    required this.controller,
    this.appBarPicker,
    this.bottomWidgetPicker,
    this.topWidgetPicker,
    this.pickerConfig = const CustomPickerLocationConfig(),
    this.onMapReady,
    this.showDefaultMarkerPickWidget = false,
    Key? key,
  }) : super(key: key);

  static PickerMapController of<T>(
    BuildContext context, {
    bool nullOk = false,
  }) {
    final _CustomPickerLocationState? result =
        context.findAncestorStateOfType<_CustomPickerLocationState>();
    if (nullOk || result != null) return result!.widget.controller;
    throw FlutterError.fromParts(
      <DiagnosticsNode>[
        ErrorSummary(
          'CustomPickerLocation.of() called with a context that does not contain an MapController.',
        ),
        ErrorDescription(
          'No CustomPickerLocation ancestor could be found starting from the context that was passed to CustomPickerLocation.of().',
        ),
        context.describeElement('The context used was')
      ],
    );
  }

  @override
  _CustomPickerLocationState createState() => _CustomPickerLocationState();
}

class _CustomPickerLocationState extends State<CustomPickerLocation> {
  GeoPoint? lastCenterMap = null;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: widget.appBarPicker,
          body: Stack(
            children: [
              Positioned.fill(
                child: OSMFlutter(
                  controller: widget.controller,
                  mapIsLoading: widget.pickerConfig.loadingWidget,
                  onMapMoved: (region) {
                    if (lastCenterMap == null ||
                        lastCenterMap != region.center) {
                      widget.controller.setMapMoving(true);
                    } else {
                      widget.controller.setMapMoving(false);
                    }
                    setState(() {
                      lastCenterMap = region.center;
                    });
                  },
                  osmOption: OSMOption(
                    isPicker: true,
                    zoomOption: widget.pickerConfig.zoomOption,
                  ),
                  onMapIsReady: widget.onMapReady,
                ),
              ),
              if (widget.showDefaultMarkerPickWidget) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedCenterMarker(
                    center: lastCenterMap,
                  ),
                ),
              ],
              if (widget.topWidgetPicker != null) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: widget.topWidgetPicker!,
                ),
              ],
              if (widget.bottomWidgetPicker != null) ...[
                widget.bottomWidgetPicker!,
              ],
            ],
          ),
        );
      },
    );
  }
}
