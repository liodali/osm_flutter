/// Endorsed Android implementation and MethodChannel transport for
/// `flutter_osm_plugin`.
library flutter_osm_android;

export 'src/android_transport/android_transport_factory.dart'
    show createDefaultAndroidMapTransport;
export 'src/android_transport/method_channel_android_map_transport.dart'
    show MethodChannelAndroidMapTransport;
