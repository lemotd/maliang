import 'package:flutter/material.dart';
import 'ai_glow_border.dart';
import '../utils/smooth_radius.dart';

/// 存储骨架卡片的 LayerLink 和尺寸，供外部光效层使用
class SkeletonGlowInfo {
  final LayerLink link;
  final Size size;
  SkeletonGlowInfo({required this.link, required this.size});
}

class SkeletonListItem extends StatefulWidget {
  /// 全局通知：当前活跃的骨架卡片光效信息
  static final activeGlows = ValueNotifier<List<SkeletonGlowInfo>>([]);

  const SkeletonListItem({super.key});

  @override
  State<SkeletonListItem> createState() => _SkeletonListItemState();
}

class _SkeletonListItemState extends State<SkeletonListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final _layerLink = LayerLink();
  final _cardKey = GlobalKey();
  SkeletonGlowInfo? _glowInfo;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _registerGlow());
  }

  void _registerGlow() {
    if (!mounted) return;
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      _glowInfo = SkeletonGlowInfo(link: _layerLink, size: box.size);
      SkeletonListItem.activeGlows.value = [
        ...SkeletonListItem.activeGlows.value,
        _glowInfo!,
      ];
    }
  }

  @override
  void dispose() {
    if (_glowInfo != null) {
      SkeletonListItem.activeGlows.value = SkeletonListItem.activeGlows.value
          .where((g) => g != _glowInfo)
          .toList();
      _glowInfo = null;
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: CompositedTransformTarget(
          link: _layerLink,
          child: KeyedSubtree(
            key: _cardKey,
            child: AIGlowBorder(
              borderRadius: smoothRadius(20),
              intensity: 0.3,
              child: _buildCardContent(isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: smoothRadius(20),
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
        final highlightColor = isDark
            ? const Color(0xFF3A3A3C)
            : const Color(0xFFF2F2F5);
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: smoothRadius(borderRadius),
            color: Color.lerp(baseColor, highlightColor, t)!,
          ),
        );
      },
    );
  }
}
