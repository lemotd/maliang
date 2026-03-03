import 'package:flutter/material.dart';

class SkeletonListItem extends StatefulWidget {
  const SkeletonListItem({super.key});

  @override
  State<SkeletonListItem> createState() => _SkeletonListItemState();
}

class _SkeletonListItemState extends State<SkeletonListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 标题占位
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Container(
                      height: 20,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          isDark
                              ? const Color(0xFF3A3A3C)
                              : const Color(0xFFE5E5EA),
                          isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFF2F2F7),
                          _animation.value,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                // 副标题占位 - 两行高度
                SizedBox(
                  height: 40,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            isDark
                                ? const Color(0xFF3A3A3C)
                                : const Color(0xFFE5E5EA),
                            isDark
                                ? const Color(0xFF2C2C2E)
                                : const Color(0xFFF2F2F7),
                            _animation.value,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                // 时间和分类占位
                Row(
                  children: [
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Container(
                          height: 14,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              isDark
                                  ? const Color(0xFF3A3A3C)
                                  : const Color(0xFFE5E5EA),
                              isDark
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFFF2F2F7),
                              _animation.value,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Container(
                          height: 14,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              isDark
                                  ? const Color(0xFF3A3A3C)
                                  : const Color(0xFFE5E5EA),
                              isDark
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFFF2F2F7),
                              _animation.value,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 缩略图占位
          SizedBox(
            width: 72,
            child: Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        isDark
                            ? const Color(0xFF3A3A3C)
                            : const Color(0xFFE5E5EA),
                        isDark
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFF2F2F7),
                        _animation.value,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
