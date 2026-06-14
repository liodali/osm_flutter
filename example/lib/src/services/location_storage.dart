import 'package:hive_ce/hive.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class SavedLocation {
  final String address;
  final GeoPoint geoPoint;
  final String? roadBase64;

  SavedLocation({
    required this.address,
    required this.geoPoint,
    this.roadBase64,
  });

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'latitude': geoPoint.latitude,
      'longitude': geoPoint.longitude,
      'roadBase64': roadBase64,
    };
  }

  factory SavedLocation.fromMap(Map<String, dynamic> map) {
    return SavedLocation(
      address: map['address'] as String,
      geoPoint: GeoPoint(
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
      ),
      roadBase64: map['roadBase64'] as String?,
    );
  }
}

class LocationStorage {
  static const String _boxName = 'saved_locations';
  static const int _maxSavedLocations = 10;
  static Box<Map>? _box;

  static Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  static Future<void> saveLocation(SavedLocation location) async {
    final box = _box;
    if (box == null) {
      return;
    }

    final newLocation = location.toMap();
    final keysToDelete = <dynamic>[];

    for (final key in box.keys) {
      final value = box.get(key);
      if (value is! Map) {
        continue;
      }

      final savedLocation = Map<dynamic, dynamic>.from(value);
      final savedAddress = savedLocation['address']?.toString();
      final savedLatitude = (savedLocation['latitude'] as num?)?.toDouble();
      final savedLongitude = (savedLocation['longitude'] as num?)?.toDouble();

      if (savedAddress == newLocation['address'] &&
          savedLatitude == newLocation['latitude'] &&
          savedLongitude == newLocation['longitude']) {
        keysToDelete.add(key);
      }
    }

    for (final key in keysToDelete) {
      await box.delete(key);
    }

    await box.add(newLocation);

    while (box.length > _maxSavedLocations) {
      await box.deleteAt(0);
    }
  }

  static Future<List<SavedLocation>> getLocations() async {
    final values = _box?.values.toList() ?? <Map<String, dynamic>>[];
    return values
        .map((e) => SavedLocation.fromMap(Map<String, dynamic>.from(e)))
        .toList()
        .reversed
        .toList();
  }

  static Future<void> clearLocations() async {
    await _box?.clear();
  }

  static Future<void> deleteLocation(int index) async {
    await _box?.deleteAt(index);
  }
}

class RouteHistoryEntry {
  final String startAddress;
  final String destinationAddress;
  final GeoPoint startPoint;
  final GeoPoint destinationPoint;
  final double? distanceKm;
  final double? durationSeconds;
  final String polylineBase64;
  final DateTime createdAt;

  RouteHistoryEntry({
    required this.startAddress,
    required this.destinationAddress,
    required this.startPoint,
    required this.destinationPoint,
    required this.polylineBase64,
    this.distanceKm,
    this.durationSeconds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'startAddress': startAddress,
      'destinationAddress': destinationAddress,
      'startLatitude': startPoint.latitude,
      'startLongitude': startPoint.longitude,
      'destinationLatitude': destinationPoint.latitude,
      'destinationLongitude': destinationPoint.longitude,
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'polylineBase64': polylineBase64,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory RouteHistoryEntry.fromMap(Map<String, dynamic> map) {
    return RouteHistoryEntry(
      startAddress: map['startAddress'] as String,
      destinationAddress: map['destinationAddress'] as String,
      startPoint: GeoPoint(
        latitude: (map['startLatitude'] as num).toDouble(),
        longitude: (map['startLongitude'] as num).toDouble(),
      ),
      destinationPoint: GeoPoint(
        latitude: (map['destinationLatitude'] as num).toDouble(),
        longitude: (map['destinationLongitude'] as num).toDouble(),
      ),
      distanceKm: (map['distanceKm'] as num?)?.toDouble(),
      durationSeconds: (map['durationSeconds'] as num?)?.toDouble(),
      polylineBase64: map['polylineBase64'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

class RouteHistoryStorage {
  static const String _boxName = 'route_history';
  static const int _maxSavedRoutes = 10;
  static Box<Map>? _box;

  static Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  static Future<void> saveRoute(RouteHistoryEntry route) async {
    final box = _box;
    if (box == null) {
      return;
    }

    await box.add(route.toMap());

    while (box.length > _maxSavedRoutes) {
      await box.deleteAt(0);
    }
  }

  static Future<List<RouteHistoryEntry>> getRoutes() async {
    final values = _box?.values.toList() ?? <Map<String, dynamic>>[];
    return values
        .map((e) => RouteHistoryEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList()
        .reversed
        .toList();
  }

  static Future<void> clearRoutes() async {
    await _box?.clear();
  }
}
