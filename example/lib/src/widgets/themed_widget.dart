import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// The app's shared forui theme.
///
/// Used both by [ThemedWidget] (per-route) and the root theme in `main.dart`
/// (above [FToaster]). They must agree on [FToasterStyle.toastAlignment]:
/// toasts capture their style from the *calling* context's theme (the
/// route-level one), not from the toaster's own theme.
final appTheme = FTheme.neutral.light.touch.copyWith(
  toasterStyle: const .delta(toastAlignment: .bottomCenter),
);

class ThemedWidget extends StatelessWidget {
  final Widget child;

  const ThemedWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return FTheme(
      // forui 0.27 removed the FThemes presets; `FTheme.neutral.light.touch` is
      // the built-in replacement (neutral colors, touch-optimized sizing).
      data: appTheme,
      child: child,
    );
  }
}
