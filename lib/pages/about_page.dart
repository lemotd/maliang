import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:figma_squircle/figma_squircle.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_button.dart';
import '../utils/scroll_edge_haptic.dart';
import '../utils/smooth_radius.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  double _scrollOffset = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCollapsed = _scrollOffset > 50;

    return Scaffold(
      backgroundColor: AppColors.surfaceLow(isDark),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, isCollapsed),
            Expanded(
              child: ScrollEdgeHaptic(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification) {
                      setState(() {
                        _scrollOffset = notification.metrics.pixels;
                      });
                    }
                    return false;
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(top: 4),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    children: [
                      const SizedBox(height: 60),
                      Center(
                        child: Column(
                          children: [
                            ClipSmoothRect(
                              radius: smoothRadius(22),
                              child: Image.asset(
                                'logo.png',
                                width: 80,
                                height: 80,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '马良神记',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurface(isDark),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'V1.0.1',
                              style: TextStyle(
                                fontSize: 14,

                                fontWeight: FontWeight.w400,
                                color: AppColors.onSurfaceQuaternary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isCollapsed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: isCollapsed ? 56 : 110,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 20,
                right: 60,
                top: 64,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  opacity: isCollapsed ? 0 : 1,
                  child: Text(
                    '关于软件',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF1A1A1A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 60,
                right: 60,
                top: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  opacity: isCollapsed ? 1 : 0,
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    child: Text(
                      '关于软件',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
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
                left: 8,
                top: 0,
                child: GlassButton(
                  icon: CupertinoIcons.back,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: isCollapsed ? 0.6 : 0,
          child: Container(height: 0.6, color: const Color(0x0F000000)),
        ),
      ],
    );
  }
}
