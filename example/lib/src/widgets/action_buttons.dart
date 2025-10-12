import 'package:flutter/material.dart' show ElevatedButton, ButtonStyle;
import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

final defaultStyle = ElevatedButton.styleFrom(
  minimumSize: const Size(48, 32),
  maximumSize: const Size(48, 48),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  ),
  padding: EdgeInsets.zero,
  elevation: 0,
);

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.child,
    this.onPressed,
    this.buttonStyle,
  });
  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle Function(ButtonStyle)? buttonStyle;
  @override
  Widget build(BuildContext context) {
    final btStyle = defaultStyle.copyWith(
      backgroundColor: WidgetStateColor.resolveWith(
        (_) => FTheme.of(context).colors.background,
      ),
    );
    return ElevatedButton(
      onPressed: onPressed,
      style:
          buttonStyle?.call(
            btStyle,
          ) ??
          btStyle,
      child: child,
    );
  }
}
