import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class MapNavigationSheet extends StatelessWidget {
  final double opacitySearch;
  final MapController controller;
  final VoidCallback activeSearchModeCallback;

  const MapNavigationSheet({
    Key? key,
    required this.opacitySearch,
    required this.controller,
    required this.activeSearchModeCallback,
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
              child: SearchCard(
                activeSearchModeCallback: activeSearchModeCallback,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SearchCard extends StatelessWidget {
  final VoidCallback activeSearchModeCallback;

  const SearchCard({
    Key? key,
    required this.activeSearchModeCallback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          SizedBox(
            height: 56,
            child: ListTile(
              onTap: () {
                activeSearchModeCallback();
              },
              contentPadding: EdgeInsets.symmetric(
                vertical: 2.0,
                horizontal: 12.0,
              ),
              leading: CirculaireIcon(
                icon: Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              title: Text(
                MaterialLocalizations.of(context).searchFieldLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Divider(
            color: Colors.grey,
            height: 1,
          ),
          SizedBox(
            height: 56,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  flex: 3,
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.0,
                    ),
                    leading: CirculaireIcon(
                      padding: EdgeInsets.all(2),
                      backgroundColor: Colors.grey,
                      icon: Icon(
                        Icons.home,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    title: Text(
                      "Home Address",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                VerticalDivider(
                  color: Colors.grey,
                ),
                Expanded(
                  flex: 1,
                  child: CustomTileList(
                    leading: CirculaireIcon(
                      backgroundColor: Colors.grey,
                      icon: Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    title: Text("Address"),
                    isVertical: false,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CirculaireIcon extends StatelessWidget {
  final Widget icon;
  final Color backgroundColor;
  final double height;
  final double width;
  final EdgeInsets? padding;

  const CirculaireIcon({
    Key? key,
    required this.icon,
    this.backgroundColor = Colors.grey,
    this.height = 28,
    this.width = 28,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: height,
      height: width,
      padding: padding,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
      ),
      child: icon,
    );
  }
}

class CustomTileList extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final bool isVertical;

  const CustomTileList({
    Key? key,
    required this.leading,
    required this.title,
    this.isVertical = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3),
      child: !isVertical
          ? Column(
              children: [
                leading,
                SizedBox(
                  height: 1,
                ),
                title,
              ],
            )
          : Row(
              children: [
                leading,
                SizedBox(
                  width: 8,
                ),
                DefaultTextStyle(
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  child: title,
                )
              ],
            ),
    );
  }
}
