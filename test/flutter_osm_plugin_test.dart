import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
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
  test("test search completion", () async {
    List<SearchInfo> suggestions = await addressSuggestion("berlin");
    expect(suggestions.length, 5);
  });

  test("test parse route Encoded to ListGeo", () async {
    String routeEncoded =
        "mfp_I__vpAYBO@K@[BuBRgBLK@UBMMC?AAKAe@FyBTC@E?IDKDA@K@]BUBSBA?E@E@A@KFUBK@mAL{CZQ@qBRUBmAFc@@}@Fu@DG?a@B[@qAF_AJ[D_E`@SBO@ODA@UDA?]JC?uBNE?OAKACa@AI]mCCUE[AK[iCWqB[{Bk@sE_@_DAICSAOIm@AIQuACOQyAG[Gc@]wBw@aFKu@y@oFCMAOIm@?KAQ?KIuDQmHE}BBQ?Q?OCq@?I?IASAg@OuF?OAi@?c@@c@Du@r@cH@U@I@G@K?E~@kJRyBf@uE@KFi@RaBBMFc@Da@@ETaC@QJ{@Ny@Ha@RiAfBuJF]DOh@yAHSf@aADIR_@\\q@w@y@e@a@CCUQaCkB{@y@GESO?_@?C?[IoCIgDMsEAYOkEAQ@Yj@kENg@ZyBBIHm@FY@GBUJk@JmA?c@?QAQG]LKDEDCHOL]FO^uA@GTu@La@`A_DJ[pAgCJSlAwBJSf@{@b@w@dAqBHQZq@LMLKRIFAL?J@HBFBp@XPHh@TTJNFTRNFd@N\\HF@J@J@@V?N@rA@dB";

    final list = await routeEncoded.toListGeo();
    final encodedRoute = await list.encodedToString();
    expect(list.isNotEmpty, true);
    expect(encodedRoute, routeEncoded);
  });
}
