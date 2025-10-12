import 'package:flutter/widgets.dart';
import 'package:forui/theme.dart';

class ThemedWidget extends StatelessWidget {
  final Widget child;

  const ThemedWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FAnimatedTheme(
      data: FTheme.of(context),
      child: child,
    );
  }
}
