import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Design-system-neutral progress indicator for web map asset loading.
class MapLoadingIndicator extends StatefulWidget {
  const MapLoadingIndicator({super.key});

  @override
  State<MapLoadingIndicator> createState() => _MapLoadingIndicatorState();
}

class _MapLoadingIndicatorState extends State<MapLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading map',
        child: RotationTransition(
          turns: _animation,
          child: const CustomPaint(
            size: Size.square(28),
            painter: _ProgressPainter(),
          ),
        ),
      );
}

class _ProgressPainter extends CustomPainter {
  const _ProgressPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      (Offset.zero & size).deflate(2),
      0,
      math.pi * 1.5,
      false,
      Paint()
        ..color = const Color(0xFF2196F3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) => false;
}
