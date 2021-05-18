import 'package:flutter/material.dart';
class MarkerOption {
 final MarkerIcon defaultMarker;
 final MarkerIcon? advancedPickerMarker;

}
class MarkerIcon extends StatelessWidget {
  final Icon? icon;
  final AssetImage? image;

  MarkerIcon({
    this.icon,
    this.image,
    Key? key,
  })  : assert(icon != null || image != null),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget? child = SizedBox.shrink();
    if (icon != null) {
      child = icon;
    } else if (image != null)
      child = Image(
        image: image!,
      );
    return child!;
  }
}
