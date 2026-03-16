import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../utils/smooth_radius.dart';

class AIGlowBorder extends StatefulWidget {
  final Widget child;
  final BorderRadius? borderRadius;

  const AIGlowBorder({super.key, required this.child, this.borderRadius});

  @override
  State<AIGlowBorder> createState() => _AIGlowBorderState();
}

class _AIGlowBorderState extends State<AIGlowBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? smoothRadius(20);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _GlowBorderPainter(
            animationValue: _controller.value,
            borderRadius: borderRadius,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _GlowBorderPainter extends CustomPainter {
  final double animationValue;
  final BorderRadius borderRadius;

  _GlowBorderPainter({
    required this.animationValue,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    final colors = <Color>[
      const Color(0xFF6366F1),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
      const Color(0xFF10B981),
      const Color(0xFF6366F1),
    ];

    final sweepAngle = 2 * math.pi;
    final startAngle = animationValue * 2 * math.pi;

    // 外层发光效果
    final outerPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: colors.map((c) => c.withOpacity(0.4)).toList(),
        stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(rect)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6.0);

    canvas.drawRRect(rrect, outerPaint);

    // 内层边框
    final innerPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: colors,
        stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(rect)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}
