import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';

class MapNavigationSheet extends StatelessWidget {
  final double opacitySearch;
  final MapController controller;

  const MapNavigationSheet({
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
          child: const Card(
            margin: EdgeInsets.zero,
            color: Colors.blue,
            shape: const RoundedRectangleBorder(
              borderRadius: const BorderRadius.only(
                topLeft: const Radius.circular(32.0),
                topRight: const Radius.circular(32.0),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 24,
          right: 24,
          child: Visibility(
            visible: opacitySearch == 0 ? false : true,
            child: Opacity(
              opacity: opacitySearch > 1.0 ? 1.0 : opacitySearch,
              child: SearchCard(),
            ),
          ),
        ),
      ],
    );
  }
}

class SearchCard extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          ListTile(
            leading: Chip(
              backgroundColor: Colors.grey,
              shape: CircleBorder(),
              label: Icon(
                Icons.search,
                color: Colors.white,
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
          Divider(
            color: Colors.grey,
          ),
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                flex: 3,
                child: ListTile(
                  leading: Chip(
                    labelPadding: EdgeInsets.all(2),
                    backgroundColor: Colors.grey,
                    shape: CircleBorder(),
                    label: Icon(
                      Icons.home,
                      color: Colors.white,
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
                  leading: Chip(
                    labelPadding: EdgeInsets.all(2),
                    backgroundColor: Colors.grey,
                    shape: CircleBorder(),
                    label: Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: Text("Address"),
                  isVertical: false,
                ),
              )
            ],
          )
        ],
      ),
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
