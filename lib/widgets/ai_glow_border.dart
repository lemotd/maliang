import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 弥散 AI 彩色动态光效边框
/// [intensity] 0.0 = 微弱光效, 1.0 = 最强光效（语音说话时）
class AIGlowBorder extends StatefulWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final double intensity; // 0.0 ~ 1.0

  const AIGlowBorder({
    super.key,
    required this.child,
    this.borderRadius,
    this.intensity = 0.3,
  });

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
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(20);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _GlowBorderPainter(
            animationValue: _controller.value,
            borderRadius: borderRadius,
            intensity: widget.intensity,
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
  final double intensity; // 0.0 ~ 1.0

  _GlowBorderPainter({
    required this.animationValue,
    required this.borderRadius,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);

    final colors = <Color>[
      const Color(0xFF6366F1), // indigo
      const Color(0xFF8B5CF6), // violet
      const Color(0xFFEC4899), // pink
      const Color(0xFFF59E0B), // amber
      const Color(0xFF06B6D4), // cyan
      const Color(0xFF6366F1), // loop back
    ];

    final startAngle = animationValue * 2 * math.pi;

    final clampedIntensity = intensity.clamp(0.0, 1.0);

    // 弥散模糊半径: 10 ~ 40
    final blurRadius = 10.0 + clampedIntensity * 30.0;
    // 外层透明度: 0.25 ~ 0.85
    final outerOpacity = 0.25 + clampedIntensity * 0.60;
    // 边框粗细: 1.5 ~ 3.5
    final strokeWidth = 1.5 + clampedIntensity * 2.0;
    // 外层扩展粗细: 6 ~ 16
    final outerStroke = 6.0 + clampedIntensity * 10.0;
    // 内层透明度: 0.5 ~ 1.0
    final innerOpacity = 0.5 + clampedIntensity * 0.5;

    // 第一层：大范围弥散光晕（最外层柔光）
    final diffusePaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: colors
            .map((c) => c.withValues(alpha: outerOpacity * 0.6))
            .toList(),
        stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(rect)
      ..strokeWidth = outerStroke + 8.0
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius * 2.0);

    canvas.drawRRect(rrect, diffusePaint);

    // 第二层：中等弥散
    final outerPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: colors.map((c) => c.withValues(alpha: outerOpacity)).toList(),
        stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(rect)
      ..strokeWidth = outerStroke
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, blurRadius);

    canvas.drawRRect(rrect, outerPaint);

    // 第三层：近距离柔光
    final nearPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: colors
            .map((c) => c.withValues(alpha: outerOpacity * 0.8))
            .toList(),
        stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(rect)
      ..strokeWidth = outerStroke * 0.6
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.outer, blurRadius * 0.5);

    canvas.drawRRect(rrect, nearPaint);

    // 第四层：柔和边框线（轻微弥散）
    final innerPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: colors.map((c) => c.withValues(alpha: innerOpacity)).toList(),
        stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(rect)
      ..strokeWidth = strokeWidth + 1.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    canvas.drawRRect(rrect, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter oldDelegate) {
    return animationValue != oldDelegate.animationValue ||
        intensity != oldDelegate.intensity;
  }
}
