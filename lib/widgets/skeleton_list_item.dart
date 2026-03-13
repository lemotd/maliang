import 'package:flutter/material.dart';
import 'ai_glow_border.dart';

class SkeletonListItem extends StatefulWidget {
  const SkeletonListItem({super.key});

  @override
  State<SkeletonListItem> createState() => _SkeletonListItemState();
}

class _SkeletonListItemState extends State<SkeletonListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getSmoothAIColor(double value) {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF10B981), // Emerald
      const Color(0xFF6366F1), // Indigo (循环)
    ];

    final scaledValue = value * (colors.length - 1);
    final index = scaledValue.floor();
    final t = scaledValue - index;

    return Color.lerp(colors[index], colors[index + 1], t)!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: AIGlowBorder(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildShimmerBox(isDark, height: 18),
                    const SizedBox(height: 4),
                    SizedBox(height: 40, child: _buildShimmerBox(isDark)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildShimmerBox(isDark, height: 12, width: 80),
                        const SizedBox(width: 8),
                        _buildShimmerBox(isDark, height: 12, width: 50),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                height: 72,
                child: Center(
                  child: _buildShimmerBox(
                    isDark,
                    width: 72,
                    height: 72,
                    borderRadius: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerBox(
    bool isDark, {
    double? width,
    double? height,
    double borderRadius = 4,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final baseColor = isDark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFE5E5EA);
        final highlightColor = _getSmoothAIColor(_controller.value);

        final intensity =
            0.2 + Curves.easeInOutSine.transform(_controller.value) * 0.15;

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: Color.lerp(baseColor, highlightColor, intensity)!,
          ),
        );
      },
    );
  }
}
