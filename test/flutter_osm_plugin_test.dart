import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin/src/utilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("calculation of distance between two points", () async {
    double distance = await distance2point(
      GeoPoint(
        longitude: 36.84612143139903,
        latitude: 11.099388684927824,
      ),
      GeoPoint(
        longitude: 36.8388023164018,
        latitude: 11.096959785428027,
      ),
    );
    expect(distance.round(), 843);
  });
}
