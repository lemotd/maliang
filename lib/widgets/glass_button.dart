import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';

class GlassButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? child;

  const GlassButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconColor,
    this.child,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with TickerProviderStateMixin {
  // 按压缩放动画
  late AnimationController _pressController;

  // 拖拽偏移弹簧回弹
  late AnimationController _springController;

  // 当前视觉偏移（平滑插值后的值）
  Offset _visualOffset = Offset.zero;
  // 原始拖拽偏移
  Offset _rawOffset = Offset.zero;
  // 弹簧起始偏移
  Offset _springStartOffset = Offset.zero;

  bool _isDragging = false;
  bool _isInBounds = true;
  static const double _boundsRadius = 30;
  // 拖拽跟随的最大像素距离（超出后阻尼）
  static const double _maxDragFollow = 14.0;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 350),
    );
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _springController.addListener(_onSpringTick);
  }

  @override
  void dispose() {
    _pressController.dispose();
    _springController.removeListener(_onSpringTick);
    _springController.dispose();
    super.dispose();
  }

  /// 阻尼函数：拖拽越远阻力越大，最大不超过 _maxDragFollow
  Offset _dampedOffset(Offset raw) {
    final dist = raw.distance;
    if (dist < 0.1) return Offset.zero;
    // 使用 log 阻尼：快速接近上限
    final damped = _maxDragFollow * (1 - math.exp(-dist / 20));
    return Offset.fromDirection(raw.direction, damped);
  }

  void _onPanStart(DragStartDetails details) {
    _springController.stop();
    setState(() {
      _isDragging = true;
      _isInBounds = true;
      _rawOffset = Offset.zero;
      _visualOffset = Offset.zero;
    });
    _pressController.forward();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _rawOffset += details.delta;
      _isInBounds = _rawOffset.distance < _boundsRadius;
      _visualOffset = _dampedOffset(_rawOffset);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isDragging && _isInBounds) {
      widget.onTap?.call();
    }

    setState(() => _isDragging = false);
    _pressController.reverse();
    _startSpringBack();
  }

  void _startSpringBack() {
    _springStartOffset = _visualOffset;

    const spring = SpringDescription(mass: 1.0, stiffness: 300, damping: 22);

    final simulation = SpringSimulation(spring, 0.0, 1.0, 0.0);
    _springController.animateWith(simulation);
  }

  void _onSpringTick() {
    final t = _springController.value;
    setState(() {
      _visualOffset = Offset.lerp(_springStartOffset, Offset.zero, t)!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor =
        widget.iconColor ??
        (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A));

    return SizedBox(
      height: 56,
      width: 60,
      child: Center(
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pressController, _springController]),
            builder: (context, child) {
              // 按压缩放：按下放大到 1.2
              final pressT = Curves.easeOut.transform(_pressController.value);
              final pressScale = 1.0 + 0.3 * pressT;

              // 拖拽变形
              final dx = _visualOffset.dx;
              final dy = _visualOffset.dy;
              final dist = _visualOffset.distance;

              // 基于偏移方向的拉伸变形
              double scaleX = 1.0;
              double scaleY = 1.0;
              Alignment anchor = Alignment.center;

              if (dist > 0.5) {
                final totalAbs = dx.abs() + dy.abs();
                final hWeight = dx.abs() / totalAbs;
                final vWeight = dy.abs() / totalAbs;

                // 沿拖拽方向拉伸，垂直方向压缩（保持体积感）
                final stretch = (dist / _maxDragFollow) * 0.25;
                scaleX = 1.0 + stretch * hWeight - stretch * 0.3 * vWeight;
                scaleY = 1.0 + stretch * vWeight - stretch * 0.3 * hWeight;

                // 锚点：拖拽反方向
                final anchorX = dx.abs() > 0.1 ? -dx.sign * hWeight : 0.0;
                final anchorY = dy.abs() > 0.1 ? -dy.sign * vWeight : 0.0;
                anchor = Alignment(anchorX, anchorY);
              }

              // 按压时的亮度变化
              final opacity = 1.0 - 0.35 * pressT;

              return Transform(
                transform: Matrix4.identity()
                  ..scale(pressScale * scaleX, pressScale * scaleY),
                alignment: anchor,
                child: Opacity(opacity: opacity, child: child),
              );
            },
            child: _buildGlassButton(isDark, effectiveIconColor),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton(bool isDark, Color iconColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF2C2C2E) : null,
              gradient: isDark
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.9),
                        Colors.white.withOpacity(0.6),
                      ],
                    ),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF3A3A3C)
                    : Colors.white.withOpacity(0.8),
                width: 0.5,
              ),
            ),
            child: Stack(
              children: [
                if (!isDark)
                  Positioned(
                    top: 2,
                    left: 6,
                    right: 6,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.6),
                            Colors.white.withOpacity(0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                Center(
                  child:
                      widget.child ??
                      Icon(widget.icon, size: 22, color: iconColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
