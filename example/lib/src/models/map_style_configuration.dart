import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:forui/forui.dart';

/// A selectable tile layer preset.
class TilePreset {
  final String id;
  final String name;
  final IconData icon;
  final CustomTile tile;
  final bool isBuiltIn;

  const TilePreset({
    required this.id,
    required this.name,
    required this.icon,
    required this.tile,
    this.isBuiltIn = false,
  });
}

enum ExampleMarkerStyle {
  icon,
  image,
}

class ExampleMapStyleConfiguration extends ChangeNotifier {
  ExampleMapStyleConfiguration._();

  static final ExampleMapStyleConfiguration instance =
      ExampleMapStyleConfiguration._();

  static const List<String> markerAssetOptions = <String>[
    'asset/taxi.png',
    'asset/pin.png',
    'asset/directionIcon.png',
  ];

  static const List<IconData> markerIconOptions = <IconData>[
    Icons.person_pin,
    Icons.location_on,
    Icons.place,
  ];

  static const List<Color> roadColorOptions = <Color>[
    Colors.red,
    Colors.blueAccent,
    Colors.green,
    Colors.orange,
    Colors.purple,
  ];

  static const List<Color> roadBorderColorOptions = <Color>[
    Colors.green,
    Colors.white,
    Colors.black,
    Colors.orange,
  ];

  static const List<double> roadBorderWidthOptions = <double>[
    4,
    8,
    10,
    14,
  ];

  static const List<RoadType> roadTypeOptions = <RoadType>[
    RoadType.car,
    RoadType.bike,
    RoadType.foot,
  ];

  static final List<TilePreset> builtInTiles = <TilePreset>[
    TilePreset(
      id: 'basic',
      name: 'Basic',
      icon: FIcons.map,
      tile: CustomTile.osm(),
      isBuiltIn: true,
    ),
    TilePreset(
      id: 'cycle',
      name: 'Cycle',
      icon: FIcons.bike,
      tile: CustomTile.cycleOSM(),
      isBuiltIn: true,
    ),
    TilePreset(
      id: 'transport',
      name: 'Transport',
      icon: FIcons.bus,
      tile: CustomTile.publicTransportationOSM(),
      isBuiltIn: true,
    ),
    TilePreset(
      id: 'vector',
      name: 'Vector',
      icon: Icons.public,
      tile: CustomTile.openFreeMap(),
      isBuiltIn: true,
    ),
    TilePreset(
      id: 'satellite',
      name: 'Satellite',
      icon: Icons.satellite,
      tile: CustomTile.satellite(),
      isBuiltIn: true,
    ),
  ];

  ExampleMarkerStyle _markerStyle = ExampleMarkerStyle.image;
  IconData _markerIcon = Icons.person_pin;
  Color _markerIconColor = Colors.red;
  double _markerIconSize = 48;
  String _markerAssetPath = 'asset/taxi.png';
  double _markerAssetWidth = 32;
  double _markerAssetHeight = 64;

  Color _roadColor = Colors.red;
  bool _hasRoadBorder = true;
  Color _roadBorderColor = Colors.green;
  double _roadBorderWidth = 10;
  RoadType _roadType = RoadType.car;
  bool _isDotted = false;
  final Map<RoadType, bool> _roadTypeDottedCache = <RoadType, bool>{
    RoadType.car: false,
    RoadType.bike: true,
    RoadType.foot: true,
  };
  String _searchLocale = 'en';
  List<TilePreset> _customTiles = <TilePreset>[];
  String _defaultTileId = 'basic';

  ExampleMarkerStyle get markerStyle => _markerStyle;
  IconData get markerIcon => _markerIcon;
  Color get markerIconColor => _markerIconColor;
  double get markerIconSize => _markerIconSize;
  String get markerAssetPath => _markerAssetPath;
  double get markerAssetWidth => _markerAssetWidth;
  double get markerAssetHeight => _markerAssetHeight;
  Color get roadColor => _roadColor;
  bool get hasRoadBorder => _hasRoadBorder;
  Color get roadBorderColor => _roadBorderColor;
  double get roadBorderWidth => _roadBorderWidth;
  RoadType get roadType => _roadType;
  bool get isDotted => _isDotted;
  String get searchLocale => _searchLocale;

  List<TilePreset> get customTiles => List.unmodifiable(_customTiles);

  List<TilePreset> get availableTiles => <TilePreset>[
    ...builtInTiles,
    ..._customTiles,
  ];

  TilePreset get defaultTile => availableTiles.firstWhere(
    (TilePreset tile) => tile.id == _defaultTileId,
    orElse: () => builtInTiles.first,
  );

  String get defaultTileId => _defaultTileId;

  set defaultTileId(String value) {
    if (_defaultTileId == value) {
      return;
    }
    _defaultTileId = value;
    notifyListeners();
  }

  void addCustomTile({
    required String name,
    required String url,
    String tileExtension = '.png',
    int tileSize = 256,
    int minZoomLevel = 2,
    int maxZoomLevel = 19,
  }) {
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    _customTiles = <TilePreset>[
      ..._customTiles,
      TilePreset(
        id: id,
        name: name,
        icon: FIcons.map,
        tile: CustomTile(
          urlsServers: <TileURLs>[TileURLs(url: url)],
          tileExtension: tileExtension,
          sourceName: id,
          tileSize: tileSize,
          minZoomLevel: minZoomLevel,
          maxZoomLevel: maxZoomLevel,
        ),
      ),
    ];
    notifyListeners();
  }

  void removeCustomTile(String id) {
    if (availableTiles.length <= 2) {
      return;
    }
    _customTiles = _customTiles
        .where((TilePreset tile) => tile.id != id)
        .toList();
    if (_defaultTileId == id) {
      _defaultTileId = 'basic';
    }
    notifyListeners();
  }

  static const Map<String, String> supportedSearchLocales = {
    'en': 'English',
    'fr': 'French',
    'ar': 'Arabic',
    'es': 'Spanish',
    'de': 'Deutsch',
  };

  static String roadTypeLabel(RoadType value) {
    switch (value) {
      case RoadType.car:
        return 'Car';
      case RoadType.bike:
        return 'Bike';
      case RoadType.foot:
        return 'Foot';
    }
  }

  static bool roadTypeIsDotted(RoadType value) {
    return value == RoadType.bike || value == RoadType.foot;
  }

  static RoadType roadTypeForDotted(bool value) {
    return value ? RoadType.bike : RoadType.car;
  }

  bool isRoadTypeDotted(RoadType value) {
    return _roadTypeDottedCache[value] ?? roadTypeIsDotted(value);
  }

  void setRoadTypeDotted(RoadType value, bool dotted) {
    if (_roadTypeDottedCache[value] == dotted &&
        (_roadType != value || _isDotted == dotted)) {
      return;
    }
    _roadTypeDottedCache[value] = dotted;
    if (_roadType == value) {
      _isDotted = dotted;
    }
    notifyListeners();
  }

  set markerStyle(ExampleMarkerStyle value) {
    if (_markerStyle == value) {
      return;
    }
    _markerStyle = value;
    notifyListeners();
  }

  set markerIcon(IconData value) {
    if (_markerIcon == value) {
      return;
    }
    _markerIcon = value;
    notifyListeners();
  }

  set markerIconColor(Color value) {
    if (_markerIconColor == value) {
      return;
    }
    _markerIconColor = value;
    notifyListeners();
  }

  set markerIconSize(double value) {
    if (_markerIconSize == value) {
      return;
    }
    _markerIconSize = value;
    notifyListeners();
  }

  set markerAssetPath(String value) {
    if (_markerAssetPath == value) {
      return;
    }
    _markerAssetPath = value;
    notifyListeners();
  }

  set markerAssetWidth(double value) {
    if (_markerAssetWidth == value) {
      return;
    }
    _markerAssetWidth = value;
    notifyListeners();
  }

  set markerAssetHeight(double value) {
    if (_markerAssetHeight == value) {
      return;
    }
    _markerAssetHeight = value;
    notifyListeners();
  }

  set roadColor(Color value) {
    if (_roadColor == value) {
      return;
    }
    _roadColor = value;
    notifyListeners();
  }

  set hasRoadBorder(bool value) {
    if (_hasRoadBorder == value) {
      return;
    }
    _hasRoadBorder = value;
    notifyListeners();
  }

  set roadBorderColor(Color value) {
    if (_roadBorderColor == value) {
      return;
    }
    _roadBorderColor = value;
    notifyListeners();
  }

  set roadBorderWidth(double value) {
    if (_roadBorderWidth == value) {
      return;
    }
    _roadBorderWidth = value;
    notifyListeners();
  }

  set roadType(RoadType value) {
    if (_roadType == value) {
      return;
    }
    _roadType = value;
    _isDotted = isRoadTypeDotted(value);
    notifyListeners();
  }

  set isDotted(bool value) {
    if (_isDotted == value) {
      return;
    }
    _isDotted = value;
    _roadType = roadTypeForDotted(value);
    _roadTypeDottedCache[_roadType] = value;
    notifyListeners();
  }

  set searchLocale(String value) {
    if (_searchLocale == value) {
      return;
    }
    _searchLocale = value;
    notifyListeners();
  }

  MarkerIcon buildMarkerIcon() {
    switch (_markerStyle) {
      case ExampleMarkerStyle.icon:
        return MarkerIcon(
          icon: Icon(
            _markerIcon,
            color: _markerIconColor,
            size: _markerIconSize,
          ),
        );
      case ExampleMarkerStyle.image:
        return MarkerIcon(
          iconWidget: Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: _markerAssetWidth,
              height: _markerAssetHeight,
              child: Image.asset(
                _markerAssetPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
    }
  }

  UserLocationMaker buildUserLocationMarker() {
    return UserLocationMaker(
      personMarker: buildMarkerIcon(),
      directionArrowMarker: buildDirectionArrowMarker(),
    );
  }

  MarkerIcon buildDirectionArrowMarker() {
    return const MarkerIcon(
      icon: Icon(
        Icons.navigation_rounded,
        size: 48,
      ),
    );
  }

  RoadOption buildRoadOption() {
    return RoadOption(
      roadWidth: 15,
      roadColor: _roadColor,
      zoomInto: true,
      isDotted: _isDotted,
      roadBorderColor: _hasRoadBorder ? _roadBorderColor : null,
      roadBorderWidth: _hasRoadBorder ? _roadBorderWidth : null,
    );
  }
}
