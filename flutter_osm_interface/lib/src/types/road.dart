import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/src/common/utilities.dart';
import 'geo_point.dart';

enum RoadType {
  car,
  foot,
  bike,
}

/// [RoadOption]
///
/// this class used to configure road in runtime by change default color
/// or width and show interest poi markers
/// and zoom to region of the road.
///
/// [roadColor]            : (Color) change the default color of the road
///
/// [roadWidth]            : (double) change width of the road
///
/// [roadBorderColor]      : (Color) it will define outline border color for road
///
/// [roadBorderWidth]      : (double) if null the road will be without border,else we will show border but if [roadBorderColor] null road border color will be the same as [roadColor]
///
/// [zoomInto]             : (bool) to zoomIn/Out that will make all the road visible in the map (default false)
class RoadOption {
  final Color roadColor;
  final double roadWidth;
  final bool zoomInto;
  final Color? roadBorderColor;
  final double? roadBorderWidth;

  const RoadOption({
    required this.roadColor,
    this.roadWidth = 5,
    this.roadBorderColor = null,
    this.zoomInto = true,
    this.roadBorderWidth = null,
  })  : assert(roadBorderWidth == null || roadBorderWidth > 0),
        assert(roadWidth > 0);

  const RoadOption.empty()
      : roadWidth = 5,
        roadColor = Colors.green,
        zoomInto = false,
        roadBorderWidth = null,
        roadBorderColor = null;

  Map toMap() {
    Map args = {};

    /// disable/show markers in start,middle,end points
    if (roadBorderWidth != null && roadBorderWidth! > 0) {
      args.putIfAbsent(
        "roadBorderWidth",
        () => roadBorderWidth,
      );
    }
    args.putIfAbsent(
      "zoomIntoRegion",
      () => zoomInto,
    );
    args.addAll(roadColor.toMapPlatform("roadColor"));
    args.putIfAbsent(
      "roadWidth",
      () => roadWidth.toDouble(),
    );
    if (roadBorderColor != null) {
      args.putIfAbsent(
        "roadBorderColor",
        () => (roadBorderColor!).toPlatform(),
      );
    }

    return args;
  }
}

/// [MultiRoadOption]
///
/// this class used to configure road in Multiple Drawing Road by change default color [roadColor]
/// that can be null or width [roadWidth] that also can be null for that specific road
///
class MultiRoadOption extends RoadOption {
  final RoadType roadType;

  const MultiRoadOption({
    required Color roadColor,
    double roadWidth = 5,
    this.roadType = RoadType.car,
    super.roadBorderColor = null,
    super.roadBorderWidth = null,
  }) : super(
          roadColor: roadColor,
          roadWidth: roadWidth,
          zoomInto: false,
        );

  const MultiRoadOption.empty()
      : this.roadType = RoadType.car,
        super(
          roadColor: Colors.green,
          zoomInto: false,

        );
}

/// [MultiRoadConfiguration]
///
/// this class used to set configuration to draw  multiple roads in the sametime
/// it required to set [startPoint] and [destinationPoint]
/// and setting [intersectPoints] is optional and the same for [roadOptionConfiguration]
/// that responsible to configure color and width of the road
///
class MultiRoadConfiguration {
  final GeoPoint startPoint;
  final GeoPoint destinationPoint;
  final List<GeoPoint> intersectPoints;
  final MultiRoadOption? roadOptionConfiguration;

  const MultiRoadConfiguration({
    required this.startPoint,
    required this.destinationPoint,
    this.intersectPoints = const [],
    this.roadOptionConfiguration,
  });
}

/// [RoadInfo]
///
/// this class is represent road information for specific road
/// has unique key to remove road
///
/// contain 3 object distance,duration and list of route
///
/// [distance] : (double) distance of  the road in km, can be null
///
/// [duration] : (double) duration of the road in seconds,can be null
///
/// [route]   :  (List of GeoPoint) the point route of the road can be empty
class RoadInfo {
  final double? distance;
  final double? duration;
  final List<GeoPoint> route;
  final List<Instruction> instructions;
  late String _key;
  RoadInfo({
    this.distance,
    this.duration,
    this.route = const [],
    this.instructions = const [],
  }) : _key = UniqueKey().toString();

  RoadInfo.fromMap(Map map)
      : _key = map["key"] ?? UniqueKey().toString(),
        this.duration = map["duration"],
        this.distance = map["distance"],
        this.instructions = map.containsKey("instructions")
            ? (map["instructions"] as List)
                .map((e) => Instruction.fromMap(e))
                .toList()
            : [],
        this.route = map.containsKey('routePoints')
            ? (map["routePoints"] as String).stringToGeoPoints()
            : [];
  RoadInfo copyWith({
    String? roadKey,
    double? distance,
    double? duration,
    List<Instruction>? instructions = const [],
    List<GeoPoint>? route = const [],
  }) {
    return RoadInfo(
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      route: route ?? this.route,
      instructions: instructions ?? this.instructions,
    )..setKey(roadKey ?? this._key);
  }

  RoadInfo copyFromMap({
    required Map map,
  }) {
    return RoadInfo(
      distance: map["duration"] ?? this.distance,
      duration: map["distance"] ?? this.duration,
      route: map.containsKey(map)
          ? (map["routePoints"] as String).stringToGeoPoints()
          : this.route,
    )..setKey(this._key);
  }

  String get key => _key;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoadInfo &&
          runtimeType == other.runtimeType &&
          _key == other._key &&
          distance == other.distance &&
          duration == other.duration &&
          route == other.route;

  @override
  int get hashCode => distance.hashCode ^ duration.hashCode ^ route.hashCode;

  @override
  String toString() {
    return "key : $key, distance: $distance, duration : $duration";
  }
}

class Instruction {
  final String instruction;
  final GeoPoint geoPoint;

  Instruction({
    required this.instruction,
    required this.geoPoint,
  });
  Instruction.fromMap(Map map)
      : instruction = map["instruction"],
        geoPoint = GeoPoint.fromMap(map["geoPoint"]);

  @override
  String toString() {
    return "$instruction";
  }
}

extension PExtRoadInfo on RoadInfo {
  void setKey(String key) {
    _key = key;
  }
}
