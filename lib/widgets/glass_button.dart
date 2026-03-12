import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class GlassButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? iconColor;

  const GlassButton({
    super.key,
    required this.icon,
    this.onTap,
    this.iconColor,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _resetController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _brightnessAnimation;

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isInBounds = true;
  static const double _boundsRadius = 30;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.15), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.18), weight: 15),
        TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.15), weight: 15),
      ],
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
    _brightnessAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 60),
        TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.65), weight: 20),
        TweenSequenceItem(tween: Tween(begin: 0.65, end: 0.6), weight: 20),
      ],
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressController.dispose();
    _resetController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _resetController.stop();
    setState(() {
      _isDragging = true;
      _isInBounds = true;
      _dragOffset = Offset.zero;
    });
    _pressController.forward();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    setState(() {
      _dragOffset += details.delta;
      final distance = _dragOffset.distance;
      _isInBounds = distance < _boundsRadius;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final wasInBounds = _isInBounds;
    final startOffset = _dragOffset;

    if (_isDragging && wasInBounds) {
      widget.onTap?.call();
    }

    setState(() {
      _isDragging = false;
    });

    _pressController.reverse();
    _animateDragReset(startOffset);
  }

  Future<void> _animateDragReset(Offset startOffset) async {
    final animation = Tween<Offset>(begin: startOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _resetController,
            curve: const Cubic(0.25, 1.0, 0.5, 1.0),
          ),
        );

    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });

    await _resetController.forward();
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
            animation: Listenable.merge([_pressController, _resetController]),
            builder: (context, child) {
              final dragDistance = _dragOffset.distance;
              final dx = _dragOffset.dx;
              final dy = _dragOffset.dy;

              final stretchFactor = 1.0 + (dragDistance / 100).clamp(0.0, 0.5);

              Alignment anchorAlignment = Alignment.center;
              double scaleX = 1.0;
              double scaleY = 1.0;

              if (dragDistance > 5) {
                final totalAbs = dx.abs() + dy.abs();
                if (totalAbs > 0) {
                  final horizontalWeight = dx.abs() / totalAbs;
                  final verticalWeight = dy.abs() / totalAbs;

                  scaleX = 1.0 + (stretchFactor - 1.0) * horizontalWeight;
                  scaleY = 1.0 + (stretchFactor - 1.0) * verticalWeight;

                  final anchorX = dx.abs() > 0.1
                      ? -dx.sign * horizontalWeight
                      : 0.0;
                  final anchorY = dy.abs() > 0.1
                      ? -dy.sign * verticalWeight
                      : 0.0;
                  anchorAlignment = Alignment(anchorX, anchorY);
                }
              }

              return Transform.scale(
                scale: _scaleAnimation.value,
                alignment: anchorAlignment,
                child: Transform(
                  transform: Matrix4.identity()..scale(scaleX, scaleY),
                  alignment: anchorAlignment,
                  child: Opacity(
                    opacity: _brightnessAnimation.value,
                    child: _buildGlassButton(isDark, effectiveIconColor),
                  ),
                ),
              );
            },
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
                Center(child: Icon(widget.icon, size: 22, color: iconColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
