import 'package:flutter/material.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

import 'geo_point.dart';
import 'marker.dart';

enum RoadType {
  car,
  foot,
  bike,
}

class RoadConfiguration {
  final Color roadColor;
  final MarkerIcon? startIcon;
  final MarkerIcon? endIcon;
  final MarkerIcon? middleIcon;

  RoadConfiguration({
    this.roadColor = Colors.blue,
    this.startIcon,
    this.middleIcon,
    this.endIcon,
  });
}

/// [RoadOption]
///
/// this class used to configure road in runtime by change default color
/// or width and show interest poi markers
/// and zoom to region of the road.
///
class RoadOption {
  final Color? roadColor;
  final int? roadWidth;
  final bool showMarkerOfPOI;
  final bool zoomInto;

  const RoadOption({
    this.roadColor,
    this.roadWidth,
    this.showMarkerOfPOI = false,
    this.zoomInto = true,
  });

  const RoadOption.empty()
      : this.roadWidth = null,
        this.roadColor = null,
        this.zoomInto = false,
        this.showMarkerOfPOI = false;
}

/// [MultiRoadOption]
///
/// this class used to configure road in Multiple Drawing Road by change default color [roadColor]
/// that can be null or width [roadWidth] that also can be null for that specific road
///
class MultiRoadOption extends RoadOption {
  final RoadType roadType;

  const MultiRoadOption({
    Color? roadColor,
    int? roadWidth,
    this.roadType = RoadType.car,
  }) : super(
          roadColor: roadColor,
          roadWidth: roadWidth,
          zoomInto: false,
          showMarkerOfPOI: false,
        );

  const MultiRoadOption.empty()
      : this.roadType = RoadType.car,
        super(roadColor: Colors.green, zoomInto: false, showMarkerOfPOI: false);
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

/// RoadInfo
/// this class is represent road information for specific road
/// contain 3 object distance,duration and list of route
/// [distance] : (double) distance of  the road in km, can be null
///
/// [duration] : (double) duration of the road in seconds,can be null
///
/// [route]   :  (List of GeoPoint) the point route of the road can be empty
class RoadInfo {
  final double? distance;
  final double? duration;
  final List<GeoPoint> route;

  RoadInfo({
    this.distance,
    this.duration,
    this.route = const [],
  });

  RoadInfo.fromMap(Map map)
      : this.duration = map["duration"],
        this.distance = map["distance"],
        this.route = decodePolyline(
          map["routePoints"],
        )
            .map((e) => GeoPoint(
                  latitude: e.first.toDouble(),
                  longitude: e.last.toDouble(),
                ))
            .toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoadInfo &&
          runtimeType == other.runtimeType &&
          distance == other.distance &&
          duration == other.duration &&
          route == other.route;

  @override
  int get hashCode => distance.hashCode ^ duration.hashCode ^ route.hashCode;

  @override
  String toString() {
    return "distance:$distance,duration:$duration";
  }
}
