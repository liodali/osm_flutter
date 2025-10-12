
import 'package:flutter/widgets.dart';
import 'package:flutter_osm_plugin_example/src/models/map_widget_configuration.dart'
    show MoreActionConfig;
import 'package:flutter_osm_plugin_example/src/pages/home/component/home_more_action.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/component/seach_map.dart'
    show SearchInMap;
import 'package:flutter_osm_plugin_example/src/widgets/action_buttons.dart';

import 'package:forui/forui.dart';

class HeaderHome extends StatelessWidget {
  const HeaderHome({
    super.key,
    required this.configuration,
    required this.isCollapsedNotifier,
  });
  final MoreActionConfig configuration;
  final ValueNotifier<bool> isCollapsedNotifier;
  @override
  Widget build(BuildContext context) {
    return FHeader.nested(
      style: (style) => style.copyWith(),
      prefixes: [
        ValueListenableBuilder(
          valueListenable: isCollapsedNotifier,
          builder: (context, value, child) {
            return MainNavigation(
              isCollapsed: value,
              onToggle: (value) => isCollapsedNotifier.value = value,
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
    this.isCollapsed = false,
    required this.onToggle,
  });
  final bool isCollapsed;
  final Function(bool) onToggle;
  @override
  Widget build(BuildContext context) {
    return ActionButton(
      onPressed: () => onToggle(!isCollapsed),
      buttonStyle: (style) => style.copyWith(
        backgroundColor: FWidgetStateMap.all(
          FTheme.of(context).colors.background,
        ),
        elevation: FWidgetStateMap.all(0),
      ),
      child: Icon(
        !isCollapsed ? FIcons.arrowLeftToLine : FIcons.arrowRightToLine,
        size: 18,
        color: FTheme.of(context).colors.secondaryForeground,
      ),
    );
  }
}
