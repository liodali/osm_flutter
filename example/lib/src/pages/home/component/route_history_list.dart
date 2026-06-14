import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin_example/src/pages/home/component/route_history_empty.dart';
import 'package:flutter_osm_plugin_example/src/services/location_storage.dart';
import 'package:forui/forui.dart';

class RouteHistoryList extends StatefulWidget {
  const RouteHistoryList({super.key});

  @override
  State<RouteHistoryList> createState() => _RouteHistoryListState();
}

class _RouteHistoryListState extends State<RouteHistoryList> {
  List<RouteHistoryEntry> _history = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final routes = await RouteHistoryStorage.getRoutes();
    if (!mounted) return;
    setState(() {
      _history = routes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return const RouteHistoryEmpty();
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: _history.length,
        separatorBuilder: (_, __) => const Divider(
          height: 8,
          thickness: 0,
        ),
        itemBuilder: (context, index) {
          return HistoryDirectionItem(
            entry: _history[index],
          );
        },
      ),
    );
  }
}

class HistoryDirectionItem extends StatelessWidget {
  const HistoryDirectionItem({
    super.key,
    required this.entry,
  });

  final RouteHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FTheme.of(context).colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: FTheme.of(context).colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              text: 'From\n',
              children: [
                TextSpan(
                  text: '${entry.startAddress}\n',
                  style: FTheme.of(context).typography.sm.copyWith(
                    color: FTheme.of(context).colors.foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                TextSpan(
                  text: 'to\n',
                  style: FTheme.of(context).typography.sm.copyWith(
                    color: FTheme.of(context).colors.foreground,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
                TextSpan(
                  text: entry.destinationAddress,
                  style: FTheme.of(context).typography.sm.copyWith(
                    color: FTheme.of(context).colors.foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ],
              style: FTheme.of(context).typography.sm.copyWith(
                color: FTheme.of(context).colors.foreground,
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FTheme.of(context).typography.sm.copyWith(
              color: FTheme.of(context).colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              [
                if (entry.distanceKm != null)
                  '${entry.distanceKm!.toStringAsFixed(2)} km',
                if (entry.durationSeconds != null)
                  '${Duration(seconds: entry.durationSeconds!.round()).inMinutes} min',
                entry.createdAt.toLocal().toString().split('.').first,
              ].join(' • '),
              style: FTheme.of(context).typography.xs.copyWith(
                color: FTheme.of(context).colors.secondaryForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
