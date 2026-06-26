import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin_example/src/common/router_config.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/component/route_history_list.dart';
import 'package:flutter_osm_plugin_example/src/services/location_storage.dart'
    show RouteHistoryEntry;
import 'package:forui/forui.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class SideBar extends StatefulWidget {
  const SideBar({
    super.key,
    required this.onToggleCallback,
    this.showToggleButton = true,
    this.topContent,
    this.onHistoryItemTap,
  });
  final Function() onToggleCallback;
  final bool showToggleButton;
  final Widget? topContent;
  final Future<void> Function(RouteHistoryEntry entry)? onHistoryItemTap;

  @override
  State<SideBar> createState() => _SideBarState();
}

class _SideBarState extends State<SideBar> {
  void _showHistory(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    if (isMobile) {
      showFSheet(
        context: context,
        side: FLayout.btt,
        builder: (context) => DecoratedBox(
          decoration: BoxDecoration(
            color: context.theme.colors.background,
            border: Border.all(
              color: context.theme.colors.border,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Direction search history',
                  style: FTheme.of(context).typography.lg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ),
                    child: RouteHistoryList(
                      onTapItem: (entry) async {
                        await widget.onHistoryItemTap?.call(entry);
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                        widget.onToggleCallback();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      showFDialog(
        context: context,
        builder: (context, style, animation) => FDialog(
          style: style,
          animation: animation,
          title: const Text('Direction search history'),
          actions: [
            FButton(
              variant: .ghost,
              onPress: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
          body: SizedBox(
            width: 400,
            child: RouteHistoryList(
              onTapItem: (entry) async {
                await widget.onHistoryItemTap?.call(entry);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.viewPaddingOf(context).top + 8,
        left: 12,
        right: 12,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'OSM Plugin',
                  style: FTheme.of(context).typography.lg.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.showToggleButton) ...[
                FTappable(
                  onPress: () => widget.onToggleCallback(),
                  child: Icon(
                    FIcons.arrowLeftToLine,
                    size: 18,
                    color: FTheme.of(context).colors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
          if (widget.topContent != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: widget.topContent!,
            ),
          ],

          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: FDivider(),
          ),
        ],
      ),
    );

    final footer = Padding(
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
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                'Settings',
                style: FTheme.of(context).typography.sm.copyWith(
                  color: FTheme.of(context).colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return PointerInterceptor(
      child: SizedBox(
        width: 280,
        child: FSidebar(
          header: header,
          footer: footer,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: FSidebarItem(
                icon: const Icon(FIcons.history),
                label: const Text('Direction History'),
                selected: false,
                onPress: () => _showHistory(context),
              ),
            ),
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
