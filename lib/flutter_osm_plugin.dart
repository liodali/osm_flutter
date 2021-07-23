library osm_flutter;

export 'package:flutter_osm_interface/flutter_osm_interface.dart'
    show
        MarkerOption,
        RoadOption,
        StaticPositionGeoPoint,
        GeoPoint,
        SearchInfo,
        MarkerIcon,
        Address,
        RectOSM,
        Road,
        RoadInfo,
        ColorMap,
        ExtGeoPoint,
        ShapeOSM,
        ExtLocationData,
        RoadException,
        GeoPointException,
        CircleOSM;

export 'src/common/utilities.dart'
    show
        earthRadius,
        addressSuggestion,
        distance2point,
        sqrtCos,
        sqrtCos2,
        sqrtSin;

// export 'src/common/osm_lib.dart'
//     show MapController, PickerMapController,
//     CustomPickerLocation, OSMFlutter,FlutterOsmPluginWeb;

export 'src/controller/map_controller.dart'
    show MapController;
export 'src/controller/picker_map_controller.dart';
export 'src/osm_flutter.dart' hide OSMFlutterState;
export 'src/widgets/copyright_osm_widget.dart';
export 'src/widgets/custom_picker_location.dart';

//export 'src/widgets/custom_picker_location.dart';
export 'src/widgets/picker_location.dart';
