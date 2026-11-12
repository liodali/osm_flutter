@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_web/src/interop/models/geo_point_js.dart';
import 'package:flutter_osm_web/src/interop/models/road_option_js.dart';
import 'package:flutter_osm_web/src/mixin_web.dart';
import 'package:flutter_osm_web/src/widgets/map_loading_indicator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routing_client_dart/routing_client_dart.dart' as routing;

@JS('drawRoad')
external set _drawRoad(JSFunction? value);

void main() {
  test('JS road option defaults are applied in Dart, including WASM', () {
    final options = RoadOptionJS(color: '#00ff00');
    expect(options.roadWidth, 5);
    expect(options.zoomInto, isTrue);
    expect(options.roadBorderWidth, 0);
    expect(options.isDotted, isFalse);
    expect(options.roadBorderColor, isNull);
  });

  tearDown(() => _drawRoad = null);

  for (final type in RoadType.values) {
    test(
      'web $type route preserves coordinates, metadata and cache key',
      () async {
        final manager = _Manager(
          routing.Route(
            distance: 1.25,
            duration: 120,
            polylineEncoded: null,
            polyline: [routing.LngLat(lng: 8.123456789, lat: 47.123456789)],
            instructions: [
              routing.RouteInstruction(
                distance: 10,
                duration: 5,
                instruction: 'Turn left',
                location: routing.LngLat(lng: 8.1, lat: 47.1),
              ),
            ],
          ),
        );
        final map = _Map(manager)..mapIdMixin = 42;
        String? key;
        List<GeoPointJs>? path;
        _drawRoad =
            ((
              JSNumber id,
              JSString roadKey,
              JSArray<GeoPointJs> points,
              JSArray<GeoPointJs> interestPoints,
              RoadOptionJS options,
            ) {
              expect(id.toDartInt, 42);
              key = roadKey.toDart;
              path = points.toDart;
              expect(interestPoints.toDart.single.lon, 9);
              return 0.toJS;
            }).toJS;

        final info = await map.drawRoad(
          GeoPoint(latitude: 47, longitude: 8),
          GeoPoint(latitude: 49, longitude: 10),
          interestPoints: [GeoPoint(latitude: 48, longitude: 9)],
          roadType: type,
        );
        expect(manager.request!.routingType.name, type.name);
        expect(manager.request!.geometries, routing.Geometries.geojson);
        expect(manager.request!.steps, isTrue);
        expect(manager.request!.hasAlternative, isFalse);
        expect(manager.request!.waypoints.map((p) => [p.lng, p.lat]), [
          [8, 47],
          [9, 48],
          [10, 49],
        ]);
        expect(path!.single.lon, 8.123456789);
        expect(info.route.single.longitude, 8.123456789);
        expect(info.distance, 1.25);
        expect(info.duration, 120);
        expect(info.instructions.single.instruction, 'Turn left');
        expect(info.instructions.single.geoPoint.longitude, 8.1);
        expect(info.key, key);
        expect(map.roadsWebCache[info.key], info);
      },
    );
  }

  test('web tolerates missing geometry', () async {
    final map = _Map(
      _Manager(
        routing.Route(
          distance: 0,
          duration: 0,
          polylineEncoded: null,
          polyline: null,
        ),
      ),
    )..mapIdMixin = 1;
    _drawRoad =
        ((
          JSNumber id,
          JSString key,
          JSArray<GeoPointJs> points,
          JSArray<GeoPointJs> interestPoints,
          RoadOptionJS options,
        ) {
          expect(points.toDart, isEmpty);
          return 0.toJS;
        }).toJS;
    final info = await map.drawRoad(
      GeoPoint(latitude: 1, longitude: 2),
      GeoPoint(latitude: 3, longitude: 4),
    );
    expect(info.route, isEmpty);
  });

  testWidgets('loading indicator needs no Material/Cupertino ancestor', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: MapLoadingIndicator()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RotationTransition), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}

class _Manager extends routing.RoutingManager {
  _Manager(this.result);
  final routing.Route result;
  routing.OSRMRequest? request;

  @override
  Future<routing.Route> getRoute({
    required covariant routing.OSRMRequest request,
  }) async {
    this.request = request;
    return result;
  }
}

class _Map with WebMixin {
  _Map(this._manager);
  final routing.RoutingManager _manager;
  @override
  routing.RoutingManager get manager => _manager;
}
