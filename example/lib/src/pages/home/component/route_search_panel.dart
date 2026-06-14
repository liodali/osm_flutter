import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/component/route_search_panel_content.dart';
import 'package:flutter_osm_plugin_example/src/services/location_storage.dart';

class RouteSearchPanel extends StatefulWidget {
  const RouteSearchPanel({
    super.key,
    required this.controller,
    this.locale = 'en',
    this.embeddedInSidebar = false,
  });

  final MapController controller;
  final String locale;
  final bool embeddedInSidebar;

  @override
  State<RouteSearchPanel> createState() => _RouteSearchPanelState();
}

class _RouteSearchPanelState extends State<RouteSearchPanel> {
  static const Map<String, String> _supportedLocales = {
    'en': 'English',
    'fr': 'French',
    'ar': 'Arabic',
    'es': 'Spanish',
    'de': 'Deutsch',
  };

  SearchInfo? _routeStart;
  SearchInfo? _routeDestination;
  String? _routeStartLabel;
  String? _routeDestinationLabel;
  RoadInfo? _currentRoad;
  List<RouteHistoryEntry> _routeHistory = [];
  bool _isDrawingRoad = false;
  String? _roadError;
  late String _locale;

  bool get _isWeb => kIsWeb;

  String get _activeLocale =>
      _supportedLocales.containsKey(_locale) ? _locale : 'en';

  String get _localeLabel => _supportedLocales[_activeLocale] ?? 'English';

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
    _loadRouteHistory();
  }

  Future<void> _loadRouteHistory() async {
    final routes = await RouteHistoryStorage.getRoutes();
    if (!mounted) {
      return;
    }

    setState(() {
      _routeHistory = routes;
    });
  }

  @override
  void didUpdateWidget(covariant RouteSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locale != widget.locale && widget.locale != _locale) {
      _locale = widget.locale;
      _refreshResolvedLabels();
    }
  }

  Future<void> _refreshResolvedLabels() async {
    final start = _routeStart;
    final destination = _routeDestination;
    if (start == null && destination == null) {
      return;
    }

    final startLabel = start == null
        ? null
        : await _resolveLocationLabel(start);
    final destinationLabel = destination == null
        ? null
        : await _resolveLocationLabel(destination);

    if (!mounted) {
      return;
    }

    setState(() {
      if (startLabel != null) {
        _routeStartLabel = startLabel;
      }
      if (destinationLabel != null) {
        _routeDestinationLabel = destinationLabel;
      }
    });
  }

  Future<String> _resolveLocationLabel(SearchInfo location) async {
    final address = location.address?.toString();
    if (address != null && address.trim().isNotEmpty) {
      return address;
    }

    final point = location.point;
    if (point == null) {
      return 'Unknown location';
    }

    final reverseAddress = await reverseGeocodeAddress(
      point,
      locale: _activeLocale,
    );
    if (reverseAddress != null && reverseAddress.trim().isNotEmpty) {
      return reverseAddress;
    }

    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  String _resolveLabelFallback(SearchInfo? location) {
    final point = location?.point;
    if (point == null) {
      return 'Unknown location';
    }

    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  Future<void> _setRoutePoint({
    required bool isStart,
    required SearchInfo location,
  }) async {
    final label = await _resolveLocationLabel(location);
    if (!mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _routeStart = location;
        _routeStartLabel = label;
      } else {
        _routeDestination = location;
        _routeDestinationLabel = label;
      }
      _roadError = null;
    });

    await _drawRouteIfReady();
  }

  Future<void> _setLocale(String locale) async {
    if (locale == _locale) {
      return;
    }

    setState(() {
      _locale = locale;
    });
    await _refreshResolvedLabels();
  }

  Future<void> _clearRouteSelection() async {
    setState(() {
      _routeStart = null;
      _routeDestination = null;
      _routeStartLabel = null;
      _routeDestinationLabel = null;
      _currentRoad = null;
      _roadError = null;
    });
    await widget.controller.clearAllRoads();
  }

  Future<void> _swapRoutePoints() async {
    setState(() {
      final previousStart = _routeStart;
      final previousStartLabel = _routeStartLabel;
      _routeStart = _routeDestination;
      _routeStartLabel = _routeDestinationLabel;
      _routeDestination = previousStart;
      _routeDestinationLabel = previousStartLabel;
      _roadError = null;
    });
    await _drawRouteIfReady();
  }

  String _statusMessage() {
    if (_roadError != null) {
      return _roadError!;
    }

    if (_routeStart == null) {
      return 'Pick a start location to draw the route.';
    }

    if (_routeDestination == null) {
      final startLabel = _routeStartLabel;
      if (startLabel == null || startLabel.trim().isEmpty) {
        return 'Now choose a destination.';
      }
      return 'From: $startLabel · Now choose a destination.';
    }

    return _isDrawingRoad ? 'Drawing route…' : _roadSummary();
  }

  Future<void> _drawRouteIfReady() async {
    final start = _routeStart?.point;
    final destination = _routeDestination?.point;

    if (start == null || destination == null) {
      return;
    }

    if (start == destination) {
      if (!mounted) {
        return;
      }
      setState(() {
        _roadError = 'Choose two different locations.';
      });
      return;
    }

    if (_isDrawingRoad) {
      return;
    }

    setState(() {
      _isDrawingRoad = true;
      _roadError = null;
    });

    try {
      await widget.controller.clearAllRoads();
      final roadInformation = await widget.controller.drawRoad(
        start,
        destination,
        roadType: RoadType.car,
        roadOption: const RoadOption(
          roadWidth: 15,
          roadColor: Colors.red,
          zoomInto: true,
          roadBorderWidth: 10.0,
          roadBorderColor: Colors.green,
          isDotted: true,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _currentRoad = roadInformation;
      });

      final routePoints = roadInformation.route;
      final encodedPolyline = routePoints.isNotEmpty
          ? await routePoints.encodedToString()
          : '';
      await RouteHistoryStorage.saveRoute(
        RouteHistoryEntry(
          startAddress: _routeStartLabel ?? _resolveLabelFallback(_routeStart),
          destinationAddress:
              _routeDestinationLabel ??
              _resolveLabelFallback(_routeDestination),
          startPoint: _routeStart!.point!,
          destinationPoint: _routeDestination!.point!,
          distanceKm: roadInformation.distance,
          durationSeconds: roadInformation.duration,
          polylineBase64: encodedPolyline,
        ),
      );
      await _loadRouteHistory();
    } on RoadException catch (e) {
      if (!mounted) {
        return;
      }
      final message = e.errorMessage() ?? 'Unable to draw the route.';
      setState(() {
        _roadError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDrawingRoad = false;
        });
      }
    }
  }

  String _roadSummary() {
    final road = _currentRoad;
    if (road == null) {
      return 'Pick both locations to draw the route.';
    }
    final distance = road.distance;
    final duration = road.duration;
    final parts = <String>[];
    if (distance != null) {
      parts.add('${distance.toStringAsFixed(2)} km');
    }
    if (duration != null) {
      parts.add('${Duration(seconds: duration.round()).inMinutes} min');
    }
    return parts.isEmpty ? 'Route ready.' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return RouteSearchPanelContent(
      embeddedInSidebar: widget.embeddedInSidebar,
      useSequentialWebInputs: _isWeb || widget.embeddedInSidebar,
      supportedLocales: _supportedLocales,
      activeLocale: _activeLocale,
      localeLabel: _localeLabel,
      statusMessage: _statusMessage(),
      isError: _roadError != null,
      routeStart: _routeStart,
      routeDestination: _routeDestination,
      routeStartLabel: _routeStartLabel,
      routeDestinationLabel: _routeDestinationLabel,
      onLocaleSelected: _setLocale,
      onSetRoutePoint: _setRoutePoint,
      onClearRouteSelection: _clearRouteSelection,
      onSwapRoutePoints: _swapRoutePoints,
      onClearDestination: () async {
        setState(() {
          _routeDestination = null;
          _routeDestinationLabel = null;
          _currentRoad = null;
          _roadError = null;
        });
        await widget.controller.clearAllRoads();
      },
      onUseCurrentLocation: _useCurrentLocation,
      routeHistory: _routeHistory,
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      final currentLocation = await widget.controller.myLocation();
      if (!mounted) {
        return;
      }

      final address = await reverseGeocodeAddress(
        currentLocation,
        locale: _activeLocale,
      );
      final searchInfo = SearchInfo(
        point: currentLocation,
        address: Address(
          name: address?.trim().isNotEmpty == true
              ? address!
              : 'Current Location',
        ),
      );

      if (_routeStart == null) {
        await _setRoutePoint(isStart: true, location: searchInfo);
      } else if (_routeDestination == null) {
        await _setRoutePoint(isStart: false, location: searchInfo);
      } else {
        await _setRoutePoint(isStart: true, location: searchInfo);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _roadError = 'Unable to get current location.';
      });
    }
  }
}
