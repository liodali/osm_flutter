import 'package:flutter/material.dart'
    show FloatingActionButton, Scaffold, Colors;
import 'package:flutter/widgets.dart';
import 'package:flutter_osm_plugin_example/src/models/map_widget_configuration.dart'
    show MoreActionConfig;
import 'package:flutter_osm_plugin_example/src/pages/home/component/home_more_action.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/component/seach_map.dart'
    show SearchInMap;

import 'package:forui/forui.dart';

class HeaderHome extends StatelessWidget {
  const HeaderHome({super.key, required this.configuration});
  final MoreActionConfig configuration;
  @override
  Widget build(BuildContext context) {
    return FHeader.nested(
      style: (style) => style.copyWith(),
      prefixes: const [
        MainNavigation(),
      ],
      title: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'home',
          style: FTheme.of(context).typography.lg,
        ),
      ),
      suffixes: [
        SizedBox(
          width: 265,
          child: SearchInMap(
            controller: configuration.controller,
          ),
        ),
        HomeMoreAction(
          configuration: configuration,
        ),
      ],
    );
  }
}

class MainNavigation extends StatelessWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      key: UniqueKey(),
      onPressed: () {
        Scaffold.of(context).openDrawer();
      },
      heroTag: "MainMenuFab",
      mini: true,
      backgroundColor: Colors.white,
      child: const Icon(FIcons.menu),
    );
  }
}
