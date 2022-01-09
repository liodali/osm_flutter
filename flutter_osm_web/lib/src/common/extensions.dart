import 'package:flutter_osm_interface/flutter_osm_interface.dart';

import '../interop/models/bounding_box_js.dart';
import '../interop/models/geo_point_js.dart';

extension ExtGeoPoint on GeoPoint {
  GeoPointJs toGeoJS() {
    return GeoPointJs(
      lon: longitude,
      lat: latitude,
    );
  }
}

extension ExtBoundingBox on BoundingBox {
  BoundingBoxJs toBoundsJS() {
    return BoundingBoxJs(
      south: south,
      north: north,
      east: east,
      west: west,
    );
  }
}
