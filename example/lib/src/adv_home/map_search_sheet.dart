import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class MapSearchSheet extends StatelessWidget {
  final double opacitySearch;
  final MapController controller;

  const MapSearchSheet({
    Key? key,
    required this.opacitySearch,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 72,
          left: 0,
          right: 0,
          bottom: 0,
          child: Card(
            margin: EdgeInsets.zero,
            color: Colors.grey[300],
            shape: const RoundedRectangleBorder(
              borderRadius: const BorderRadius.only(
                topLeft: const Radius.circular(16.0),
                topRight: const Radius.circular(16.0),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 32,
          right: 32,
          child: Visibility(
            visible: opacitySearch == 0 ? false : true,
            child: Opacity(
              opacity: opacitySearch > 1.0 ? 1.0 : opacitySearch,
              child: Card(
                child: TextField(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
