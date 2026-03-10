import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart';
import '../pages/settings_page.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onSettingsTap;
  final double scrollOffset;

  const MainAppBar({super.key, this.onSettingsTap, this.scrollOffset = 0});

  @override
  Widget build(BuildContext context) {
    final isCollapsed = scrollOffset > 50;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: isCollapsed ? 52 : 100,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 20,
                right: 60,
                top: 44,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  opacity: isCollapsed ? 0 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '马良神记',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF1A1A1A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '一键记，随时记',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF8E8E93),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 60,
                top: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  opacity: isCollapsed ? 1 : 0,
                  child: Container(
                    height: 52,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '马良神记',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFF1A1A1A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 0,
                child: _SettingsButton(
                  onTap: onSettingsTap ?? () => _handleSettingsTap(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSettingsTap(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(100);
}

class _SettingsButton extends StatefulWidget {
  final VoidCallback onTap;

  const _SettingsButton({required this.onTap});

  @override
  State<_SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<_SettingsButton>
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
      widget.onTap();
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

    _resetController.reset();

    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });

    await _resetController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
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
                child: Transform(
                  transform: Matrix4.identity()..scale(scaleX, scaleY),
                  alignment: anchorAlignment,
                  child: Opacity(
                    opacity: _brightnessAnimation.value,
                    child: _buildGlassButton(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
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
                  child: SvgPicture.asset(
                    'assets/icons/setting.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      isDark
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF1A1A1A),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
