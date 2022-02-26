import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class WebApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: "/home",
      routes: {
        "/home": (ctx) => WebTestOsm(),
      },
    );
  }
}

class WebTestOsm extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _WebTestOsmState();
}

class _WebTestOsmState extends State<WebTestOsm> with OSMMixinObserver {
  late final MapController controller = MapController(
    initMapWithUserPosition: false,
    initPosition: GeoPoint(
      latitude: 47.4358055,
      longitude: 8.4737324,
    ),
  );
  final Key key = GlobalKey();

  bool activateDrawRoad = false;
  bool activateCollectGetGeoPointsToDraw = false;

  List<GeoPoint> roadPoints = [];

  @override
  void initState() {
    super.initState();
    controller.addObserver(this);
    controller.listenerMapSingleTapping.addListener(onMapSingleTap);

    controller.listenerRegionIsChanging.addListener(() {
      if (controller.listenerRegionIsChanging.value != null) {
        print("${controller.listenerRegionIsChanging.value}");
      }
    });
  }

  void onMapSingleTap() async {
    if (controller.listenerMapSingleTapping.value != null) {
      final GeoPoint geoPoint = controller.listenerMapSingleTapping.value!;
      await controller.addMarker(
        geoPoint,
        markerIcon: MarkerIcon(
          icon: Icon(Icons.push_pin),
        ),
      );
      if (activateCollectGetGeoPointsToDraw) {
        setState(() {
          roadPoints.add(geoPoint);
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("osm web"),
        actions: [
          IconButton(
            onPressed: () async {
              await controller.currentLocation();
            },
            icon: Icon(Icons.location_history),
          ),
          IconButton(
            onPressed: () async {
              if (!activateCollectGetGeoPointsToDraw && roadPoints.isEmpty) {
                setState(() {
                  activateCollectGetGeoPointsToDraw = true;
                });
              } else if (activateCollectGetGeoPointsToDraw && roadPoints.isNotEmpty) {
                await controller.drawRoad(
                  roadPoints.first,
                  roadPoints.last,
                  roadOption: RoadOption(
                    zoomInto: true,
                    roadColor: Colors.red,
                  ),
                );
                setState(() {
                  activateCollectGetGeoPointsToDraw = false;
                  roadPoints.clear();
                });
              }
            },
            icon: Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: Builder(
        builder: (ctx) {
          return OSMFlutter(
            key: key,
            controller: controller,
            initZoom: 5,
            onGeoPointClicked: (geoPoint) async {
              if (geoPoint == GeoPoint(latitude: 47.442475, longitude: 8.4680389)) {
                await controller.setMarkerIcon(
                  geoPoint,
                  MarkerIcon(
                    icon: Icon(
                      Icons.bus_alert,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                );
              }
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text(
                  geoPoint.toString(),
                ),
                action: SnackBarAction(
                  label: "hide",
                  onPressed: () {
                    ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                  },
                ),
              ));
            },
            mapIsLoading: Center(
              child: Text("map is Loading"),
            ),
            markerOption: MarkerOption(
              defaultMarker: MarkerIcon(
                icon: Icon(
                  Icons.add_location,
                  color: Colors.amber,
                ),
              ),
            ),
            staticPoints: [
              StaticPositionGeoPoint(
                "line 1",
                MarkerIcon(
                  icon: Icon(
                    Icons.train,
                    color: Colors.green,
                    size: 48,
                  ),
                ),
                [
                  GeoPoint(latitude: 47.4333594, longitude: 8.4680184),
                  GeoPoint(latitude: 47.4317782, longitude: 8.4716146),
                ],
              )
            ],
            showContributorBadgeForOSM: true,
          );
        },
      ),
    );
  }

  @override
  Future<void> mapIsReady(bool isReady) async {
    if (isReady) {
      await controller.changeLocation(
        GeoPoint(
          latitude: 47.433358,
          longitude: 8.4690184,
        ),
      );
      await controller.setZoom(zoomLevel: 12);

      double zoom = await controller.getZoom();
      print("zoom:$zoom");
      await controller.addMarker(
        GeoPoint(latitude: 47.442475, longitude: 8.4680389),
        markerIcon: MarkerIcon(
          icon: Icon(
            Icons.car_repair,
            color: Colors.black45,
            size: 48,
          ),
        ),
      );
    }
  }
}
