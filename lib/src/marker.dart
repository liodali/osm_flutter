import 'package:flutter/material.dart';

class MarkerIcon extends StatelessWidget {
  final Icon icon;
  final AssetImage image;
  MarkerIcon({this.icon, this.image}) : assert(icon != null || image != null);

  @override
  Widget build(BuildContext context) {
    Widget child = SizedBox.shrink();
    if (icon != null) {
      child = icon;
    } else if (image != null)
      child = Image(
        image: image,
      );
    return child;
  }
}
