import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';

import '../controller/picker_map_controller.dart';
import '../osm_flutter.dart';

class CustomPickerLocationConfig {
  final Widget? loadingWidget;
  final MarkerIcon? advancedMarkerPicker;

  final double stepZoom;
  final double initZoom;
  final double minZoomLevel;
  final double maxZoomLevel;

  const CustomPickerLocationConfig({
    this.loadingWidget,
    this.advancedMarkerPicker,
    this.stepZoom = 1,
    this.initZoom = 2,
    this.minZoomLevel = 2,
    this.maxZoomLevel = 18,
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

  CustomPickerLocation({
    required this.controller,
    this.appBarPicker,
    this.bottomWidgetPicker,
    this.topWidgetPicker,
    this.pickerConfig = const CustomPickerLocationConfig(),
    this.onMapReady,
    Key? key,
  }) : super(key: key);

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
                  markerOption: widget.pickerConfig.advancedMarkerPicker != null
                      ? MarkerOption(
                          advancedPickerMarker:
                              widget.pickerConfig.advancedMarkerPicker,
                        )
                      : null,
                  isPicker: true,
                  mapIsLoading: widget.pickerConfig.loadingWidget,
                  stepZoom: widget.pickerConfig.stepZoom,
                  initZoom: widget.pickerConfig.initZoom,
                  minZoomLevel: widget.pickerConfig.minZoomLevel,
                  maxZoomLevel: widget.pickerConfig.maxZoomLevel,
                  onMapIsReady: widget.onMapReady,
                ),
              ),
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
