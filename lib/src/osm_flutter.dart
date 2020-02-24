import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:location_permissions/location_permissions.dart';

class OSMFlutter extends StatefulWidget {
  final bool currentLocation;
  final bool trackMyPosition;
  final bool showZoomController;
  final GeoPoint initPosition;
  OSMFlutter({
    this.currentLocation = true,
    this.trackMyPosition = false,
    this.showZoomController = false,
    this.initPosition,
  }) ;

  static OSMFlutterState of<T>(BuildContext context, {bool nullOk = false}) {
    assert(context != null);
    assert(nullOk != null);
    final OSMFlutterState result =
        context.findAncestorStateOfType<OSMFlutterState>();
    if (nullOk || result != null) return result;
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary(
          'FlutterOsmState.of() called with a context that does not contain an FlutterOsm.'),
      ErrorDescription(
          'No FlutterOsm ancestor could be found starting from the context that was passed to FlutterOsm.of().'),
      context.describeElement('The context used was')
    ]);
  }

  @override
  OSMFlutterState createState() => OSMFlutterState();
}

class OSMFlutterState extends State<OSMFlutter> {
  //permission status
  PermissionStatus _permission;
  //_OsmCreatedCallback _osmCreatedCallback;
  _OsmController _osmController;
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 200), () async {
      //check location permission
      _permission = await LocationPermissions().checkPermissionStatus();
      if (_permission == PermissionStatus.denied) {
        //request location permission
        _permission = await LocationPermissions().requestPermissions();
        if (_permission == PermissionStatus.granted) {
          await _checkServiceLocation();
        }
      } else if (_permission == PermissionStatus.granted) {
        if(widget.currentLocation)
          await _checkServiceLocation();
      }
      if (widget.initPosition != null) {
        print(widget.initPosition.longitude);
        await initLocationPosition(widget.initPosition);
      }
    });
  }

  Future<void> initLocationPosition(GeoPoint p) async {
    this._osmController.initPosition(p);
  }

  void zoom(int zoom) {
    this._osmController.zoom(zoom);
  }

  void currentLocation() {
    this._osmController.currentLocation();
  }

  Future<void> _checkServiceLocation() async {
    ServiceStatus serviceStatus =
        await LocationPermissions().checkServiceStatus();
    if (serviceStatus == ServiceStatus.disabled) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            title: Text("GPS service is disabled"),
            content: Text(
                "We need to get your current location,you should turn on your gps location "),
            actions: <Widget>[
              FlatButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "annuler",
                  style: TextStyle(color: Colors.black),
                ),
              ),
              FlatButton(
                onPressed: () => Navigator.pop(context),
                color: Theme.of(context).primaryColor,
                child: Text(
                  "ok",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else if (serviceStatus == ServiceStatus.enabled) {
      currentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'plugins.dali.hamza/osmview',
        onPlatformViewCreated: _onPlatformViewCreated,
        //creationParamsCodec:  StandardMessageCodec(),
      );
    }
    return Text(
        '$defaultTargetPlatform is not yet supported by the osm plugin');
  }

  void _onPlatformViewCreated(int id) {
    this._osmController = _OsmController._(id);
  }
}

class _OsmController {
  _OsmController._(int id)
      : _channel = new MethodChannel('plugins.dali.hamza/osmview_$id');

  final MethodChannel _channel;

  Future<void> zoom(int zoom) async {
    assert(zoom != null);
    return await _channel.invokeMethod('Zoom', zoom);
  }

  Future<void> currentLocation() async {
    return await _channel.invokeMethod('currentLocation', null);
  }

  Future<void> enableTracking() async {
    return await _channel.invokeMethod('trackMe', null);
  }

  Future<void> initPosition(GeoPoint p)async {
    return await _channel.invokeListMethod("initPosition", {"lon":p.longitude,"lat":p.latitude});
  }
}
