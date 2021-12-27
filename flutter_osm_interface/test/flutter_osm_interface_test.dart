import 'package:flutter_osm_interface/src/types/types.dart';
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
}
