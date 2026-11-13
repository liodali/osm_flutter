import 'package:dio/dio.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routing_client_dart/routing_client_dart.dart' as routing;

void main() {
  test(
    'real 1.0.8 client parses OSRM GeoJSON and embeds instructions',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://routing.invalid'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.uri.path, contains('/routed-car/route/v1/driving/'));
            expect(options.uri.queryParameters['geometries'], 'geojson');
            expect(options.uri.queryParameters['steps'], 'true');
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'code': 'Ok',
                  'routes': [
                    {
                      'distance': 1250.0,
                      'duration': 120.0,
                      'geometry': {
                        'type': 'LineString',
                        'coordinates': [
                          [8.123456789, 47.123456789],
                          [9.0, 48.0],
                        ],
                      },
                      'legs': [
                        {
                          'distance': 1250.0,
                          'duration': 120.0,
                          'steps': [
                            {
                              'name': 'Test Street',
                              'distance': 1250.0,
                              'duration': 120.0,
                              'driving_side': 'right',
                              'mode': 'driving',
                              'intersections': <Object>[],
                              'maneuver': {
                                'type': 'depart',
                                'bearing_before': 0,
                                'bearing_after': 0,
                                'location': [8.123456789, 47.123456789],
                              },
                            },
                          ],
                        },
                      ],
                    },
                  ],
                },
              ),
            );
          },
        ),
      );
      addTearDown(() => dio.close(force: true));
      final controller = _MapController(
        routing.RoutingManager(
          configuration: routing.RoutingManagerConfiguration(
            osrmServerDioClient: dio,
          ),
        ),
      );
      final host = _MapHost();
      controller.setBaseOSMController(host);
      addTearDown(controller.dispose);
      final info = await controller.drawRoad(
        GeoPoint(latitude: 47.123456789, longitude: 8.123456789),
        GeoPoint(latitude: 48, longitude: 9),
      );
      expect(info.distance, 1.25);
      expect(info.duration, 120);
      expect(info.route.first.longitude, 8.123456789);
      expect(info.instructions.single.instruction, isNotEmpty);
      expect(info.instructions.single.geoPoint.latitude, 47.123456789);
    },
  );

  for (final type in RoadType.values) {
    test(
      'drawRoad preserves $type, waypoint order, units and instructions',
      () async {
        final manager = _RoutingManager(
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
        final controller = _MapController(manager);
        final host = _MapHost();
        controller.setBaseOSMController(host);
        addTearDown(controller.dispose);

        final info = await controller.drawRoad(
          GeoPoint(latitude: 47, longitude: 8),
          GeoPoint(latitude: 49, longitude: 10),
          intersectPoint: [GeoPoint(latitude: 48, longitude: 9)],
          roadType: type,
        );

        final request = manager.request!;
        expect(request.waypoints.map((p) => [p.lng, p.lat]), [
          [8, 47],
          [9, 48],
          [10, 49],
        ]);
        expect(request.routingType.name, type.name);
        expect(request.geometries, routing.Geometries.geojson);
        expect(request.steps, isTrue);
        expect(request.hasAlternative, isFalse);
        expect(info.distance, 1.25); // kilometres, not metres
        expect(info.duration, 120); // seconds
        expect(info.instructions.single.instruction, 'Turn left');
        expect(info.instructions.single.geoPoint.longitude, 8.1);
        expect(info.route.single.longitude, 8.123456789);
        expect(host.path, info.route);
        expect(host.key, info.key);
      },
    );
  }

  test('missing geometry does not cause a null assertion', () async {
    final controller = _MapController(
      _RoutingManager(
        routing.Route(
          distance: 0,
          duration: 0,
          polylineEncoded: null,
          polyline: null,
        ),
      ),
    );
    final host = _MapHost();
    controller.setBaseOSMController(host);
    addTearDown(controller.dispose);
    final info = await controller.drawRoad(
      GeoPoint(latitude: 1, longitude: 2),
      GeoPoint(latitude: 3, longitude: 4),
    );
    expect(info.route, isEmpty);
    expect(info.instructions, isEmpty);
    expect(host.path, isEmpty);
  });
}

class _RoutingManager extends routing.RoutingManager {
  _RoutingManager(this.result);
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

class _MapController extends MapController {
  _MapController(this._manager)
    : super(initPosition: GeoPoint(latitude: 47, longitude: 8));

  final routing.RoutingManager _manager;
  @override
  routing.RoutingManager get osrmManager => _manager;
}

class _MapHost implements IBaseOSMController {
  List<GeoPoint>? path;
  String? key;

  @override
  Future<String> drawRoadManually(
    String key,
    List<GeoPoint> path,
    RoadOption option,
  ) async {
    this.key = key;
    this.path = path;
    return key;
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
