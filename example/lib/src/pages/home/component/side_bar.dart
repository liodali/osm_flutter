import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_osm_plugin_example/src/common/router_config.dart';
import 'package:forui/forui.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class SideBar extends StatelessWidget {
  const SideBar({
    super.key,
    this.width = 250,
    required this.onToggleCallback,
  });
  final double width;
  final Function() onToggleCallback;

  @override
  Widget build(BuildContext context) {
    return PointerInterceptor(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: width,
        child: FSidebar(
          header: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.viewPaddingOf(context).top + 8,
              left: 12,
              right: 12,
              bottom: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'OSM Plugin',
                    style: FTheme.of(context).typography.lg.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FTappable(
                  onPress: () => onToggleCallback(),
                  child: Icon(
                    FIcons.arrowLeftToLine,
                    size: 18,
                    color: FTheme.of(context).colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          footer: Padding(
            padding: const EdgeInsets.all(12),
            child: FTappable(
              onPress: () => context.router.pushSettings(),
              child: Row(
                children: [
                  Icon(
                    FIcons.settings,
                    size: 18,
                    color: FTheme.of(context).colors.mutedForeground,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Settings',
                    style: FTheme.of(context).typography.sm.copyWith(
                      color: FTheme.of(context).colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          children: [
            FSidebarGroup(
              label: const Text('Navigation'),
              children: [
                FSidebarItem(
                  icon: const Icon(FIcons.house),
                  label: const Text('Home'),
                  selected: true,
                  onPress: () {},
                ),
                FSidebarItem(
                  icon: const Icon(FIcons.bookOpen),
                  label: const Text('Examples'),
                  initiallyExpanded: true,
                  children: [
                    FSidebarItem(
                      label: const Text('Search Example'),
                      onPress: () => context.router.pushSearch(),
                    ),
                    FSidebarItem(
                      label: const Text('Hook Example'),
                      onPress: () => context.router.pushHook(),
                    ),
                    FSidebarItem(
                      label: const Text('Old Home Example'),
                      onPress: () => context.router.pushOldHome(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
