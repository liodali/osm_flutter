import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class RouteHistoryEmpty extends StatelessWidget {
  const RouteHistoryEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FIcons.history,
              size: 40,
              color: FTheme.of(context).colors.mutedForeground,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'No direction history yet',
                style: FTheme.of(context).typography.sm.copyWith(
                  color: FTheme.of(context).colors.secondaryForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Your recent searches will appear here',
                style: FTheme.of(context).typography.xs.copyWith(
                  color: FTheme.of(context).colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
