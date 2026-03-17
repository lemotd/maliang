import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../pages/settings_page.dart';
import '../widgets/glass_button.dart';
import 'responsive_layout.dart';

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              height: isCollapsed ? 56 : 130,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '马良神记',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFF1A1A1A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '一键记，随时记',
                            style: TextStyle(
                              fontSize: 14,
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
                        height: 56,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '马良神记',
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
                    right: 8,
                    top: 0,
                    child: GlassButton(
                      icon: CupertinoIcons.settings,
                      onTap: onSettingsTap ?? () => _handleSettingsTap(context),
                      child: Builder(
                        builder: (context) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          return SvgPicture.asset(
                            'assets/icons/setting.svg',
                            width: 22,
                            height: 22,
                            colorFilter: ColorFilter.mode(
                              isDark
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFF1A1A1A),
                              BlendMode.srcIn,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSettingsTap(BuildContext context) {
    final page = const SettingsPage();
    if (!pushToDetailPane(context, page)) {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => page));
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(100);
}
