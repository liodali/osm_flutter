import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:forui/forui.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class SearchInMap extends StatelessWidget {
  const SearchInMap({
    super.key,
    this.controller,
    this.label = 'Search location',
    this.selectedAddress,
    this.onSelected,
    this.onClear,
    this.compact = false,
    this.locale = 'en',
  });

  final MapController? controller;
  final String label;
  final String? selectedAddress;
  final ValueChanged<SearchInfo>? onSelected;
  final VoidCallback? onClear;
  final bool compact;
  final String locale;

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
          title: label,
          locale: locale,
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
      await controller!.goToLocation(selectedLocation!.point!);
    }
  }

  String _subtitle() {
    if (selectedAddress == null || selectedAddress!.trim().isEmpty) {
      return 'Tap to search';
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
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FTheme.of(context).typography.sm.copyWith(
                        color: colors.secondaryForeground,
                      ),
                    ),
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
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
  const _LocationSearchSheet({required this.title, required this.locale});

  final String title;
  final String locale;

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final List<SearchInfo> _suggestions = [];
  Timer? _debounce;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleQueryChanged);
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
          locale: widget.locale,
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
                widget.title,
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _searchController.text.trim().length < 3
                    ? Center(
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
                              onTap: () {
                                Navigator.of(context).pop(suggestion);
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
