import 'package:flutter_osm_interface/flutter_osm_interface.dart';
import 'package:flutter_osm_interface/src/common/utilities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

void main() {
  test("decode ", () async {
    var list = decodePolyline(
      "exo`Hc_vr@Q\\@d@JFb@|@LTVj@HPJRLXd@jAXv@HVLf@Ld@OJeAbBi@x@gC|DaAlBO`@M\\IVs@|AyBrF{@|By@nBO^CFUl@s@dBM^o@xAg@pAEJMZUh@OPSNa@ZOSQOWKiAc@}Aw@cAg@q@_@]S]Yc@a@u@}@]g@OUBG@G?IAEAACECCEAG?G@EBQQa@]a@]{@o@KIQMMKEEIIa@]]_@KIa@m@g@w@MG@w@?SAa@Aa@C]Eq@KkBG}@Am@@a@Fc@FSJS|AiBxA_BLQNWf@gA",
    );

    print(list);
  });

  test("eq geoP", () {
    final p1 = GeoPoint(latitude: 15.031, longitude: 44.12073);
    final p2 = GeoPoint(latitude: 15.031, longitude: 44.12073);
    expect(p1.toString() == p2.toString(), true);
  });
  test("not eq geoPs", () {
    final p1 = GeoPoint(latitude: 15.031, longitude: 44.12073);
    final p2 = GeoPoint(latitude: 15.0312, longitude: 44.12073);
    expect(p1.toString() == p2.toString(), false);
  });
  test("test bounding box is world", () {
    final box = BoundingBox(north: 85.05, east: 180, south: -85.06, west: -180);
    expect(box.isWorld(), true);
    final box2 =
        BoundingBox(north: 84.05, east: 170, south: -85.06, west: -180);
    expect(box2.isWorld(), false);
  });

  test('convert urls for android', () {
    final tileUrls =
        TileURLs(url: "https://{s}.tile.opentopomap.org/", subdomains: [
      "a",
      "b",
      "c",
    ]);
    final urlsAndroid = tileUrls.toMapAndroid();
    final result = [
      "https://a.tile.opentopomap.org/",
      "https://b.tile.opentopomap.org/",
      "https://c.tile.opentopomap.org/",
    ];
    expect(urlsAndroid, result);
  });
  test('convert urls for ios', () {
    final tileUrls = TileURLs(
      url: "https://{s}.tile.opentopomap.org/",
      subdomains: [
        "a",
        "b",
        "c",
      ],
    );
    final urlsIOS = tileUrls.toMapiOS();
    final result = {
      "url": "https://{s}.tile.opentopomap.org/",
      "subdomains": [
        "a",
        "b",
        "c",
      ],
    };
    expect(urlsIOS, result);
  });
  test('convert urls for ios with key', () {
    final tileUrls = TileURLs(
      url: "https://{s}.tile.opentopomap.org/{z}/{x}/{y}",
      subdomains: [
        "a",
        "b",
        "c",
      ],
    );
    final urlsIOS = tileUrls.toMapiOS();

    expect(urlsIOS["url"], "https://{s}.tile.opentopomap.org");
  });
  test('convert urls for web', () {
    final tileUrls = TileURLs(
      url: "https://{s}.tile.opentopomap.org/",
      subdomains: [
        "a",
        "b",
        "c",
      ],
    );
    final urlsWeb = tileUrls.toWeb();
    final result = [
      "https://{s}.tile.opentopomap.org/",
      'abc',
    ];
    expect(urlsWeb, result);
  });

  test('test isEqual1eX', () {
    expect(isEqual1eX(0.001), true);
    expect(isEqual1eX(0.01), false);
    expect(isEqual1eX(1e5), true);
    expect(isEqual1eX(1e9), true);
    expect(isEqual1eX(1e10), false);
    expect(isEqual1eX(1e-3), true);
    expect(isEqual1eX(1e-4), true);
  });
  test('test isEqual for geoPoint', () {
    final p1 =
        GeoPoint(latitude: 47.43751121525967, longitude: 8.473693728446962);
    final p2 =
        GeoPoint(latitude: 47.43751121525967, longitude: 8.473693728446962);
        final p3 =
        GeoPoint(latitude: 47.43751421525967, longitude: 8.473695728446962);
    expect(p1.isEqual(p2), true);
    expect(p1.isEqual(p3), false);
  });
}
