//
//  GeoPointRadians.swift
//  flutter_osm_plugin
//
//  Created by Dali Hamza on 27.08.23.
//
//  credit from [https://github.com/googlemaps/google-maps-ios-utils/blob/main/src/GeometryUtils/Internal/LatLngRadians.swift]
//

import Foundation
import CoreLocation
/// A location (latitude or longitude) represented in radians
typealias LocationRadians = Double

/// A struct representing a latitude, longitude value represented in radians
struct LatLngRadians {
  var latitude: LocationRadians
  var longitude: LocationRadians

  static func +(left: LatLngRadians, right: LatLngRadians) -> LatLngRadians {
    return LatLngRadians(
      latitude: left.latitude + right.latitude,
      longitude: left.longitude + right.longitude
    )
  }

  static func -(left: LatLngRadians, right: LatLngRadians) -> LatLngRadians {
    return LatLngRadians(
      latitude: left.latitude - right.latitude,
      longitude: left.longitude - right.longitude
    )
  }
}

extension LocationRadians {
  var degrees: CLLocationDegrees {
    return self * (180 / .pi)
  }
}

extension LatLngRadians {
  var locationCoordinate2D: CLLocationCoordinate2D {
    return CLLocationCoordinate2D(latitude: latitude.degrees, longitude: longitude.degrees)
  }

  /// Returns the signed area of a triangle composing `latLng1`, `latLng2`, and the north pole.
  /// Formula derived from "Area of a spherical triangle given two edges and the included angle"
  /// as per "Spherical Trigonometry" by Todhunter, page 71, section 103, point 2.
  /// See http://books.google.com/books?id=3uBHAAAAIAAJ&pg=PA71
  static func polarTriangleArea(_ latLng1: LatLngRadians, _ latLng2: LatLngRadians) -> Double {
    let deltaLng = latLng1.longitude - latLng2.longitude
    let tan1 = tan(((.pi / 2) - latLng1.latitude) / 2)
    let tan2 = tan(((.pi / 2) - latLng2.latitude) / 2)
    let t = tan1 * tan2
    return 2 * atan2(t * sin(deltaLng), 1 + t * cos(deltaLng))
  }
}

extension CLLocationCoordinate2D {
  var latLngRadians: LatLngRadians {
    LatLngRadians(latitude: latitude.radians, longitude: longitude.radians)
  }
}

extension CLLocationDegrees {
  var radians: LocationRadians {
    return self * (.pi / 180)
  }
}
