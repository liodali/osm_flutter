import 'package:flutter/material.dart';
import 'package:flutter_osm_interface/src/common/utilities.dart';
import 'geo_point.dart';

enum RoadType {
  car,
  foot,
  bike,
  mixed,
}

class Road {
  final String id;
  final List<Polyline> polylines;

  Road({
    required this.id,
    required this.polylines,
  });
  Map toMap() => {
        'key': id,
        "segments": polylines.map((p) {
          return p.toMap();
        }).toList(),
      };
}

class Polyline {
  final String id;
  final String encodedPolyline;
  final PolylineOption polylineOption;

  Polyline({
    required this.id,
    required this.encodedPolyline,
    required this.polylineOption,
  });
  Map<String, dynamic> toMap() => {
        'id': id,
        'polylineEncoded': encodedPolyline,
        'option': polylineOption.toMap(),
      };
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
class PolylineOption {
  final Color roadColor;
  final double roadWidth;
  final Color? roadBorderColor;
  final double? roadBorderWidth;
  final bool isDotted;

  const PolylineOption({
    required this.roadColor,
    this.roadWidth = 5,
    this.roadBorderColor,
    this.isDotted = false,
    this.roadBorderWidth,
  })  : assert(roadBorderWidth == null || roadBorderWidth > 0),
        assert(roadWidth > 0);

  const PolylineOption.empty()
      : roadWidth = 5,
        roadColor = Colors.green,
        isDotted = false,
        roadBorderWidth = 0,
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
      "roadWidth",
      () => roadWidth,
    );
    args.addAll(roadColor.toMapPlatform("roadColor"));
    args.putIfAbsent(
      "isDotted",
      () => isDotted,
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
/// [segments]   :  (List of RoadSegment) the segment of the road
class RoadInfo {
  final double? distance;
  final double? duration;
  final List<RoadSegment> segments;
  late String _key;
  RoadInfo({
    this.distance,
    this.duration,
    this.segments = const [],
  }) : _key = UniqueKey().toString();

  RoadInfo.fromMap(Map map)
      : _key = map["key"] ?? UniqueKey().toString(),
        duration = map["duration"],
        distance = map["distance"],
        segments = map.containsKey("segments")
            ? (map["instructions"] as List)
                .map((e) => RoadSegment.fromMap(e))
                .toList()
            : [];
  RoadInfo copyWith({
    String? roadKey,
    double? distance,
    double? duration,
    List<RoadSegment>? segments = const [],
  }) {
    return RoadInfo(
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      segments: segments ?? this.segments,
    )..setKey(roadKey ?? _key);
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
          segments == other.segments;

  @override
  int get hashCode => distance.hashCode ^ duration.hashCode ^ segments.hashCode;

  @override
  String toString() {
    return "key : $key, distance: $distance, duration : $duration";
  }
}

class RoadSegment {
  final double? distance;
  final double? duration;
  final List<GeoPoint> route;
  final List<Instruction> instructions;

  RoadSegment({
    required this.distance,
    required this.duration,
    required this.route,
    required this.instructions,
  });
  RoadSegment.fromMap(Map map)
      : duration = map["duration"],
        distance = map["distance"],
        instructions = map.containsKey("instructions")
            ? (map["instructions"] as List)
                .map((e) => Instruction.fromMap(e))
                .toList()
            : [],
        route = map.containsKey('routePoints')
            ? (map["routePoints"] as String).stringToGeoPoints()
            : [];
  RoadSegment copyFromMap({
    required Map map,
  }) {
    return RoadSegment(
        distance: map["duration"] ?? distance,
        duration: map["distance"] ?? duration,
        route: map.containsKey(map)
            ? (map["route"] as String).stringToGeoPoints()
            : route,
        instructions: map.containsKey("instructions")
            ? (map["instructions"] as List)
                .map((e) => Instruction.fromMap(e))
                .toList()
            : []);
  }

  RoadSegment copyWith({
    String? roadKey,
    double? distance,
    double? duration,
    List<GeoPoint>? route = const [],
    List<Instruction>? instructions = const [],
  }) {
    return RoadSegment(
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      route: route ?? this.route,
      instructions: instructions ?? this.instructions,
    );
  }
}

class Instruction {
  final String instruction;
  final GeoPoint geoPoint;
  final double distance;
  final double duration;

  Instruction({
    required this.instruction,
    required this.geoPoint,
    required this.distance,
    required this.duration,
  });
  Instruction.fromMap(Map map)
      : instruction = map["instruction"],
        distance = map["distance"],
        duration = map["duration"],
        geoPoint = GeoPoint.fromMap(map["geoPoint"]);

  @override
  String toString() {
    return instruction;
  }
}

extension PExtRoadInfo on RoadInfo {
  void setKey(String key) {
    _key = key;
  }
}
