import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

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
  test("test search completion", () async {
    List<SearchInfo> suggestions = await addressSuggestion("berlin");
    expect(suggestions.length, 5);
  });

  test("decode ", () async {
    var list = decodePolyline(
      "exo`Hc_vr@Q\\@d@JFb@|@LTVj@HPJRLXd@jAXv@HVLf@Ld@OJeAbBi@x@gC|DaAlBO`@M\\IVs@|AyBrF{@|By@nBO^CFUl@s@dBM^o@xAg@pAEJMZUh@OPSNa@ZOSQOWKiAc@}Aw@cAg@q@_@]S]Yc@a@u@}@]g@OUBG@G?IAEAACECCEAG?G@EBQQa@]a@]{@o@KIQMMKEEIIa@]]_@KIa@m@g@w@MG@w@?SAa@Aa@C]Eq@KkBG}@Am@@a@Fc@FSJS|AiBxA_BLQNWf@gA",
    );

    print(list);
  });
}
