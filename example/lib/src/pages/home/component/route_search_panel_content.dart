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
    required this.useSequentialWebInputs,
    required this.supportedLocales,
    required this.activeLocale,
    required this.localeLabel,
    required this.statusMessage,
    required this.isError,
    required this.routeStart,
    required this.routeDestination,
    required this.routeStartLabel,
    required this.routeDestinationLabel,
    required this.onLocaleSelected,
    required this.onSetRoutePoint,
    required this.onClearRouteSelection,
    required this.onSwapRoutePoints,
    required this.onClearDestination,
  });

  final bool embeddedInSidebar;
  final bool useSequentialWebInputs;
  final Map<String, String> supportedLocales;
  final String activeLocale;
  final String localeLabel;
  final String statusMessage;
  final bool isError;
  final SearchInfo? routeStart;
  final SearchInfo? routeDestination;
  final String? routeStartLabel;
  final String? routeDestinationLabel;
  final Future<void> Function(String locale) onLocaleSelected;
  final Future<void> Function({
    required bool isStart,
    required SearchInfo location,
  }) onSetRoutePoint;
  final Future<void> Function() onClearRouteSelection;
  final Future<void> Function() onSwapRoutePoints;
  final Future<void> Function() onClearDestination;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  statusMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FTheme.of(context).typography.sm.copyWith(
                    color: isError ? Colors.red : colors.secondaryForeground,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _LocaleSelector(
                  activeLocale: activeLocale,
                  localeLabel: localeLabel,
                  supportedLocales: supportedLocales,
                  onLocaleSelected: onLocaleSelected,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: useSequentialWebInputs
                ? _RouteInputs.sequential(
                    locale: activeLocale,
                    routeStart: routeStart,
                    routeDestination: routeDestination,
                    routeStartLabel: routeStartLabel,
                    routeDestinationLabel: routeDestinationLabel,
                    onSetRoutePoint: onSetRoutePoint,
                    onClearRouteSelection: onClearRouteSelection,
                    onClearDestination: onClearDestination,
                  )
                : _RouteInputs.dual(
                    locale: activeLocale,
                    routeStart: routeStart,
                    routeDestination: routeDestination,
                    routeStartLabel: routeStartLabel,
                    routeDestinationLabel: routeDestinationLabel,
                    onSetRoutePoint: onSetRoutePoint,
                    onClearRouteSelection: onClearRouteSelection,
                    onClearDestination: onClearDestination,
                  ),
          ),
          _ActionRow(
            hasSelection: routeStart != null || routeDestination != null,
            onSwapRoutePoints: onSwapRoutePoints,
            onClearRouteSelection: onClearRouteSelection,
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

class _LocaleSelector extends StatelessWidget {
  const _LocaleSelector({
    required this.activeLocale,
    required this.localeLabel,
    required this.supportedLocales,
    required this.onLocaleSelected,
  });

  final String activeLocale;
  final String localeLabel;
  final Map<String, String> supportedLocales;
  final Future<void> Function(String locale) onLocaleSelected;

  @override
  Widget build(BuildContext context) {
    final colors = FTheme.of(context).colors;

    return FPopoverMenu(
      menuAnchor: Alignment.topRight,
      childAnchor: Alignment.bottomRight,
      menu: [
        FItemGroup(
          children: supportedLocales.entries
              .map(
                (entry) => FItem(
                  title: Text(entry.value),
                  selected: entry.key == activeLocale,
                  prefix: entry.key == activeLocale
                      ? const Icon(Icons.check, size: 16)
                      : null,
                  onPress: () => onLocaleSelected(entry.key),
                ),
              )
              .toList(),
        ),
      ],
      builder: (context, controller, _) => FTappable(
        onPress: controller.toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language, size: 16),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  localeLabel,
                  style: FTheme.of(context).typography.sm,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.arrow_drop_down, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteInputs extends StatelessWidget {
  const _RouteInputs.sequential({
    required this.locale,
    required this.routeStart,
    required this.routeDestination,
    required this.routeStartLabel,
    required this.routeDestinationLabel,
    required this.onSetRoutePoint,
    required this.onClearRouteSelection,
    required this.onClearDestination,
  }) : showDestinationWhenStartExists = true;

  const _RouteInputs.dual({
    required this.locale,
    required this.routeStart,
    required this.routeDestination,
    required this.routeStartLabel,
    required this.routeDestinationLabel,
    required this.onSetRoutePoint,
    required this.onClearRouteSelection,
    required this.onClearDestination,
  }) : showDestinationWhenStartExists = false;

  final String locale;
  final SearchInfo? routeStart;
  final SearchInfo? routeDestination;
  final String? routeStartLabel;
  final String? routeDestinationLabel;
  final Future<void> Function({
    required bool isStart,
    required SearchInfo location,
  }) onSetRoutePoint;
  final Future<void> Function() onClearRouteSelection;
  final Future<void> Function() onClearDestination;
  final bool showDestinationWhenStartExists;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchInMap(
          compact: true,
          locale: locale,
          label: 'From',
          selectedAddress: routeStartLabel,
          onSelected: (value) => onSetRoutePoint(isStart: true, location: value),
          onClear: routeStart == null
              ? null
              : () async {
                  await onClearRouteSelection();
                },
        ),
        if (!showDestinationWhenStartExists || routeStart != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SearchInMap(
              compact: true,
              locale: locale,
              label: 'To',
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
