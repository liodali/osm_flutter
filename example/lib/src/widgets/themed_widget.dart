import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class ThemedWidget extends StatelessWidget {
  final Widget child;

  const ThemedWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FTheme(
      data: FThemes.zinc.light.touch,
      child: child,
    );
  }
}
