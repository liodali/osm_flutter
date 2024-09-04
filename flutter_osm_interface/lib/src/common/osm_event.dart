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
  MapInitialization(super.mapId, super.isMapReady);
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
  TapEvent(super.mapId, super.position);
}

class SingleTapEvent extends TapEvent {
  SingleTapEvent(super.mapId, super.position);
}

class LongTapEvent extends TapEvent {
  LongTapEvent(super.mapId, super.position);
}

class GeoPointEvent extends EventOSM<GeoPoint> {
  GeoPointEvent(super.mapId, super.position);
}

class RoadTapEvent extends EventOSM<RoadInfo> {
  RoadTapEvent(super.mapId, super.road);
}

class UserLocationEvent extends EventOSM<UserLocation> {
  UserLocationEvent(super.mapId, super.userLocation);
}

class RegionIsChangingEvent extends EventOSM<Region> {
  RegionIsChangingEvent(super.mapId, super.region);
}
class IosMapInit extends EventOSM<bool> {
  IosMapInit(super.mapId, super.loaded);
}
