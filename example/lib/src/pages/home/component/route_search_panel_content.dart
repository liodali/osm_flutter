import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/component/seach_map.dart'
    show SearchInMap;
import 'package:forui/forui.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class RouteSearchPanelContent extends StatelessWidget {
  const RouteSearchPanelContent({
    super.key,
    required this.embeddedInSidebar,
    required this.statusMessage,
    required this.isError,
    required this.routeStart,
    required this.routeDestination,
    required this.routeStartLabel,
    required this.routeDestinationLabel,
    required this.onSetRoutePoint,
    required this.onClearRouteSelection,
    required this.onSwapRoutePoints,
    required this.onClearDestination,
    required this.onUseCurrentLocation,
    this.collapsed = false,
    this.onToggleCollapsed,
  });

  final bool embeddedInSidebar;
  final String statusMessage;
  final bool isError;
  final SearchInfo? routeStart;
  final SearchInfo? routeDestination;
  final String? routeStartLabel;
  final String? routeDestinationLabel;
  final Future<void> Function({
    required bool isStart,
    required SearchInfo location,
  })
  onSetRoutePoint;
  final Future<void> Function() onClearRouteSelection;
  final Future<void> Function() onSwapRoutePoints;
  final Future<void> Function() onClearDestination;
  final VoidCallback? onUseCurrentLocation;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final colors = FTheme.of(context).colors;
    final panel = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!collapsed)
            Text(
              statusMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FTheme.of(context).typography.sm.copyWith(
                color: isError ? Colors.red : colors.secondaryForeground,
              ),
            ),
          Padding(
            padding: EdgeInsets.only(top: collapsed ? 0 : 10),
            child: _RouteInputs(
              routeStart: routeStart,
              routeDestination: collapsed ? null : routeDestination,
              routeStartLabel: routeStartLabel,
              routeDestinationLabel: routeDestinationLabel,
              onSetRoutePoint: onSetRoutePoint,
              onClearRouteSelection: onClearRouteSelection,
              onClearDestination: onClearDestination,
              onUseCurrentLocation: onUseCurrentLocation,
              showDestination: !collapsed,
            ),
          ),
          if (!collapsed) ...[
            _ActionRow(
              hasSelection: routeStart != null || routeDestination != null,
              onSwapRoutePoints: onSwapRoutePoints,
              onClearRouteSelection: onClearRouteSelection,
            ),
          ],
          if (onToggleCollapsed != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onToggleCollapsed,
                icon: Icon(
                  collapsed ? FIcons.chevronDown : FIcons.chevronUp,
                  color: colors.mutedForeground,
                ),
              ),
            ),
        ],
      ),
    );

    if (embeddedInSidebar) {
      return panel;
    }

    return PointerInterceptor(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: panel,
        ),
      ),
    );
  }
}

class _RouteInputs extends StatelessWidget {
  const _RouteInputs({
    required this.routeStart,
    required this.routeDestination,
    required this.routeStartLabel,
    required this.routeDestinationLabel,
    required this.onSetRoutePoint,
    required this.onClearRouteSelection,
    required this.onClearDestination,
    this.onUseCurrentLocation,
    this.showDestination = true,
  });

  final SearchInfo? routeStart;
  final SearchInfo? routeDestination;
  final String? routeStartLabel;
  final String? routeDestinationLabel;
  final Future<void> Function({
    required bool isStart,
    required SearchInfo location,
  })
  onSetRoutePoint;
  final Future<void> Function() onClearRouteSelection;
  final Future<void> Function() onClearDestination;
  final VoidCallback? onUseCurrentLocation;
  final bool showDestination;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchInMap(
          compact: true,
          placeholder: 'Start location',
          selectedAddress: routeStartLabel,
          onSelected: (value) =>
              onSetRoutePoint(isStart: true, location: value),
          onClear: routeStart == null
              ? null
              : () async {
                  await onClearRouteSelection();
                },
          onUseCurrentLocation: onUseCurrentLocation,
        ),
        if (showDestination && routeStart != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SearchInMap(
              compact: true,
              placeholder: 'Destination location',
              selectedAddress: routeDestinationLabel,
              onSelected: (value) =>
                  onSetRoutePoint(isStart: false, location: value),
              onClear: routeDestination == null
                  ? null
                  : () async {
                      await onClearDestination();
                    },
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.hasSelection,
    required this.onSwapRoutePoints,
    required this.onClearRouteSelection,
  });

  final bool hasSelection;
  final Future<void> Function() onSwapRoutePoints;
  final Future<void> Function() onClearRouteSelection;

  @override
  Widget build(BuildContext context) {
    if (!hasSelection) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              await onSwapRoutePoints();
            },
            icon: const Icon(Icons.swap_vert),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: IconButton(
              onPressed: () async {
                await onClearRouteSelection();
              },
              icon: const Icon(Icons.clear_all),
            ),
          ),
        ],
      ),
    );
  }
}
