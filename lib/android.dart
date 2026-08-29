/// Typed Android controller and MethodChannel fallback APIs.
///
/// The optional JNI command transport is provided by
/// `package:flutter_osm_android_jni`.
library flutter_osm_plugin_android;

export 'package:flutter_osm_interface/flutter_osm_interface.dart'
    show
        AndroidMapAcknowledgement,
        AndroidMapBackend,
        AndroidMapError,
        AndroidMapEvent,
        AndroidMapException,
        AndroidMapPlatform,
        AndroidMapReady,
        AndroidMapTap,
        AndroidMapTapKind,
        AndroidMapTransport,
        AndroidMapTransportFactory,
        AndroidMarkerTap,
        AndroidRegionChanged,
        AndroidUserLocationChanged,
        MarkerId,
        RoadId,
        ShapeId,
        StaticPositionId;
export 'src/android_transport/android_transport_factory.dart'
    show createDefaultAndroidMapTransport;
export 'src/android_transport/method_channel_android_map_transport.dart'
    show MethodChannelAndroidMapTransport;
export 'src/controller/android_map_controller.dart'
    show
        AndroidLocationPermissionRequester,
        AndroidMapCamera,
        AndroidMapController,
        AndroidMapLayers,
        AndroidMapLocation,
        AndroidMapMarkers,
        AndroidMapRoads,
        AndroidMapShapes,
        AndroidMapStaticPositions;
