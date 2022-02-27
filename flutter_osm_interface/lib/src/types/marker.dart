import 'package:flutter/material.dart';

class MarkerOption {
  final MarkerIcon? defaultMarker;
  final MarkerIcon? advancedPickerMarker;

  MarkerOption({
    this.defaultMarker,
    this.advancedPickerMarker,
  });

  MarkerOption copyWith({
    MarkerIcon? defaultMarker,
    MarkerIcon? advancedPickerMarker,
  }) {
    return MarkerOption(
        defaultMarker: defaultMarker ?? this.defaultMarker,
        advancedPickerMarker: advancedPickerMarker ?? this.advancedPickerMarker);
  }
}

class UserLocationMaker {
  final MarkerIcon personMarker;
  final MarkerIcon directionArrowMarker;

  UserLocationMaker({
    required this.personMarker,
    required this.directionArrowMarker,
  });
}

class AssetMarker {
  final AssetImage image;
  final double? scaleAssetImage;
  final Color? color;

  AssetMarker({
    required this.image,
    this.scaleAssetImage,
    this.color,
  });
}

class MarkerIcon extends StatelessWidget {
  final Icon? icon;
  final AssetMarker? assetMarker;
  final Widget? iconWidget;

  const MarkerIcon({
    this.icon,
    this.assetMarker,
    this.iconWidget,
    Key? key,
  })  : assert((icon != null && assetMarker == null && iconWidget == null) ||
            (iconWidget != null && assetMarker == null && icon == null) ||
            (assetMarker != null && icon == null && iconWidget == null)),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget? child = SizedBox.shrink();
    if (icon != null) {
      child = icon;
    } else if (assetMarker != null) {
      child = Image.asset(
        assetMarker!.image.assetName,
        scale: assetMarker!.scaleAssetImage,
        color: assetMarker!.color,
      );
    } else if (iconWidget != null) {
      return iconWidget!;
    }

    return child!;
  }
}
