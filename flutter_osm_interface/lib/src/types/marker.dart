import 'package:flutter/material.dart';

typedef IconAnchorOffset = ({double x, double y});

enum Anchor {
  center("center", (0.5, 0.5)),
  left("left", (1, 0.5)),
  right("right", (0, 0.5)),
  top("top", (0.5, 1)),
  bottom("bottom", (0.5, 0)),
  top_left("top-left", (1, 1)),
  top_right("top-right", (0, 1)),
  bottom_left("bottom-left", (1, 0)),
  bottom_right("bottom-right", (0, 0));

  const Anchor(this.name, this.value);
  final String name;
  final (double, double) value;

  dynamic toMapAndroid() {
      return [
        value.$1,
        value.$2,
      ];
  }

  String toMapIOS() => name;

}

class IconAnchor {
  final Anchor anchor;
  final IconAnchorOffset? offset;

  IconAnchor({
    this.anchor = Anchor.center,
    this.offset,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      "x": anchor.value.$1,
      "y": anchor.value.$2,
      "anchor": anchor.name,
    };
    if (offset != null) {
      map["offset"] = {
        "x": offset!.x,
        "y": offset!.y,
      };
    }
    return map;
  }
}

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
      advancedPickerMarker: advancedPickerMarker ?? this.advancedPickerMarker,
    );
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
