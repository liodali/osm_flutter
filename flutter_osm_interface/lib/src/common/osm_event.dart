import 'package:flutter_osm_interface/src/types/types.dart';

abstract class EventOSM<T> {
  /// The ID of the Map this event is associated to.
  final int mapId;

  /// The value wrapped by this event
  final T value;

  /// Build a Map Event, that relates a mapId with a given value.
  ///
  /// The `mapId` is the id of the map that triggered the event.
  /// `value` may be `null` in events that don't transport any meaningful data.
  EventOSM(this.mapId, this.value);
}

class MapInitialization extends EventOSM<bool> {
  MapInitialization(int mapId, bool isMapReady) : super(mapId, isMapReady);
}

class MapRestoration extends EventOSM<void> {
  MapRestoration(
    int mapId,
  ) : super(
          mapId,
          null,
        );
}

class TapEvent extends EventOSM<GeoPoint> {
  TapEvent(int mapId, GeoPoint position) : super(mapId, position);
}

class SingleTapEvent extends TapEvent {
  SingleTapEvent(int mapId, GeoPoint position) : super(mapId, position);
}

class LongTapEvent extends TapEvent {
  LongTapEvent(int mapId, GeoPoint position) : super(mapId, position);
}

class GeoPointEvent extends EventOSM<GeoPoint> {
  GeoPointEvent(int mapId, GeoPoint position) : super(mapId, position);
}

class RoadTapEvent extends EventOSM<RoadInfo> {
  RoadTapEvent(int mapId, RoadInfo road) : super(mapId, road);
}

class UserLocationEvent extends EventOSM<UserLocation> {
  UserLocationEvent(int mapId, UserLocation userLocation) : super(mapId, userLocation);
}

class RegionIsChangingEvent extends EventOSM<Region> {
  RegionIsChangingEvent(int mapId, Region region) : super(mapId, region);
}
class IosMapInit extends EventOSM<bool> {
  IosMapInit(int mapId, bool loaded) : super(mapId, loaded);
}
