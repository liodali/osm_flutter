import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:flutter_osm_plugin_example/src/models/map_style_configuration.dart';
import 'package:flutter_osm_plugin_example/src/services/location_storage.dart';
import 'package:forui/forui.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class SearchInMap extends StatelessWidget {
  const SearchInMap({
    super.key,
    this.controller,
    this.placeholder = 'Start location',
    this.selectedAddress,
    this.onSelected,
    this.onClear,
    this.onUseCurrentLocation,
    this.compact = false,
  });

  final MapController? controller;
  final String placeholder;
  final String? selectedAddress;
  final ValueChanged<SearchInfo>? onSelected;
  final VoidCallback? onClear;
  final VoidCallback? onUseCurrentLocation;
  final bool compact;

  Future<void> _openSearchSheet(BuildContext context) async {
    final selectedLocation = await showModalBottomSheet<SearchInfo>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FTheme.of(context).colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _LocationSearchSheet(
          placeholder: placeholder,
          onUseCurrentLocation: onUseCurrentLocation,
        ),
      ),
    );

    if (selectedLocation?.point == null) {
      return;
    }

    if (onSelected != null) {
      onSelected!(selectedLocation!);
      return;
    }

    if (controller != null) {
      await controller!.moveTo(selectedLocation!.point!);
    }
  }

  String _subtitle() {
    if (selectedAddress == null || selectedAddress!.trim().isEmpty) {
      return placeholder;
    }
    return selectedAddress!;
  }

  @override
  Widget build(BuildContext context) {
    final colors = FTheme.of(context).colors;
    final horizontalPadding = compact ? 12.0 : 14.0;
    final verticalPadding = compact ? 10.0 : 12.0;
    final subtitleStyle = compact
        ? FTheme.of(context).typography.sm
        : FTheme.of(context).typography.md;
    return Material(
      color: colors.background,
      child: InkWell(
        onTap: () => _openSearchSheet(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  FIcons.search,
                  size: compact ? 16 : 18,
                  color: colors.foreground,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FTheme.of(context).typography.sm.copyWith(
                        color: colors.secondaryForeground,
                      ),
                    ),
                    if (selectedAddress != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _subtitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: subtitleStyle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onUseCurrentLocation != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onUseCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Use current location',
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child:
                    selectedAddress != null &&
                        selectedAddress!.trim().isNotEmpty
                    ? IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onClear,
                        icon: const Icon(Icons.close),
                      )
                    : Icon(
                        Icons.keyboard_arrow_down,
                        color: colors.secondaryForeground,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet({
    required this.placeholder,
    this.onUseCurrentLocation,
  });

  final String placeholder;
  final VoidCallback? onUseCurrentLocation;

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final List<SearchInfo> _suggestions = [];
  List<SavedLocation> _savedLocations = [];
  Timer? _debounce;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleQueryChanged);
    _loadSavedLocations();
  }

  Future<void> _loadSavedLocations() async {
    final locations = await LocationStorage.getLocations();
    if (mounted) {
      setState(() {
        _savedLocations = locations;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_handleQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    if (mounted) {
      setState(() {});
    }
    _onQueryChanged();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();

    if (query.length < 3) {
      setState(() {
        _loading = false;
        _error = null;
        _suggestions.clear();
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await addressSuggestion(
          query,
          limitInformation: 8,
          locale: ExampleMapStyleConfiguration.instance.searchLocale,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _suggestions
            ..clear()
            ..addAll(results);
          _loading = false;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _loading = false;
          _error = 'Unable to load suggestions';
        });
      }
    });
  }

  String _displayText(SearchInfo info) {
    final text = info.address?.toString();
    if (text != null && text.trim().isNotEmpty) {
      return text;
    }
    final point = info.point;
    if (point == null) {
      return 'Unknown location';
    }
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = FTheme.of(context).colors;
    final typography = FTheme.of(context).typography;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.placeholder,
                style: typography.lg,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: PointerInterceptor(
              child: FTextField(
                control: FTextFieldControl.managed(
                  controller: _searchController,
                ),
                autofocus: true,
                textInputAction: TextInputAction.search,
                hint: 'Search for a location',
                prefixBuilder: (context, style, variants) =>
                    FTextField.prefixIconBuilder(
                      context,
                      style,
                      variants,
                      const Icon(Icons.search),
                    ),
                clearable: (value) => value.text.isNotEmpty,
              ),
            ),
          ),
          if (widget.onUseCurrentLocation != null &&
              _searchController.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PointerInterceptor(
                child: FTappable(
                  onPress: () {
                    widget.onUseCurrentLocation!();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.my_location, color: colors.foreground),
                        const SizedBox(width: 12),
                        Text(
                          'Use current location',
                          style: typography.md.copyWith(
                            color: colors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_savedLocations.isNotEmpty &&
              _searchController.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Latest searched locations',
                  style: typography.sm.copyWith(
                    color: colors.secondaryForeground,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _searchController.text.trim().length < 3
                    ? _savedLocations.isNotEmpty
                          ? ListView.separated(
                              key: const ValueKey('saved'),
                              itemCount: _savedLocations.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final location = _savedLocations[index];
                                return PointerInterceptor(
                                  child: ListTile(
                                    leading: const Icon(Icons.bookmark),
                                    title: Text(
                                      location.address,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      '${location.geoPoint.latitude.toStringAsFixed(5)}, ${location.geoPoint.longitude.toStringAsFixed(5)}',
                                    ),
                                    onTap: () {
                                      Navigator.of(context).pop(
                                        SearchInfo(
                                          point: location.geoPoint,
                                          address: Address(
                                            name: location.address,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            )
                          : Center(
                              key: const ValueKey('empty-query'),
                              child: Text(
                                'Type at least 3 characters to search.',
                                style: typography.sm.copyWith(
                                  color: colors.secondaryForeground,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                    : _loading
                    ? const Center(
                        key: ValueKey('loading'),
                        child: CircularProgressIndicator(),
                      )
                    : _error != null
                    ? Center(
                        key: const ValueKey('error'),
                        child: Text(
                          _error!,
                          style: typography.sm.copyWith(
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : _suggestions.isEmpty
                    ? Center(
                        key: const ValueKey('no-results'),
                        child: Text(
                          'No locations found.',
                          style: typography.sm.copyWith(
                            color: colors.secondaryForeground,
                          ),
                        ),
                      )
                    : ListView.separated(
                        key: const ValueKey('results'),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final suggestion = _suggestions[index];
                          return PointerInterceptor(
                            child: ListTile(
                              leading: const Icon(Icons.place_outlined),
                              title: Text(
                                _displayText(suggestion),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: suggestion.point == null
                                  ? null
                                  : Text(
                                      '${suggestion.point!.latitude.toStringAsFixed(5)}, ${suggestion.point!.longitude.toStringAsFixed(5)}',
                                    ),
                              onTap: () async {
                                final point = suggestion.point;
                                if (point != null) {
                                  await LocationStorage.saveLocation(
                                    SavedLocation(
                                      address: _displayText(suggestion),
                                      geoPoint: point,
                                    ),
                                  );
                                }

                                if (context.mounted) {
                                  Navigator.of(context).pop(suggestion);
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
