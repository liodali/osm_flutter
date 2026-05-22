import 'package:flutter/widgets.dart';
import 'package:flutter_osm_plugin_example/src/models/map_widget_configuration.dart'
    show MoreActionConfig;
import 'package:flutter_osm_plugin_example/src/pages/home/component/home_more_action.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/component/seach_map.dart'
    show SearchInMap;
import 'package:flutter_osm_plugin_example/src/pages/home/component/side_bar.dart';
import 'package:flutter_osm_plugin_example/src/widgets/action_buttons.dart';

import 'package:forui/forui.dart';

class HeaderHome extends StatelessWidget {
  const HeaderHome({
    super.key,
    required this.configuration,
  });
  final MoreActionConfig configuration;
  @override
  Widget build(BuildContext context) {
    return FHeader.nested(
      style: const .delta(),
      prefixes: [
        MainNavigation(
          onOpen: () async {
            await showFSheet(
              context: context,
              side: FLayout.ltr,
              builder: (context) => SideBar(
                onToggleCallback: () => Navigator.of(context).pop(),
              ),
            );
          },
        ),
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
  const MainNavigation({
    super.key,
    required this.onOpen,
  });
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    return ActionButton(
      onPressed: onOpen,
      buttonStyle: (style) => style.copyWith(
        backgroundColor: .all(
          FTheme.of(context).colors.background,
        ),
        elevation: .all(0),
      ),
      child: Icon(
        FIcons.menu,
        size: 18,
        color: FTheme.of(context).colors.secondaryForeground,
      ),
    );
  }
}
