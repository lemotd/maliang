import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_button.dart';
import '../utils/scroll_edge_haptic.dart';
import '../utils/smooth_radius.dart';
import 'ai_model_settings_page.dart';
import 'backup_settings_page.dart';
import 'about_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
                      _buildSettingsItem(
                        context,
                        title: 'AI 大模型设置',
                        subtitle: '配置 API 地址或模型',
                        icon: CupertinoIcons.cube,
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const AiModelSettingsPage(),
                            ),
                          );
                        },
                      ),
                      _buildSettingsItem(
                        context,
                        title: '备份与恢复',
                        subtitle: '导入、导出记忆数据',
                        icon: CupertinoIcons.arrow_2_circlepath,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const BackupSettingsPage(),
                            ),
                          );
                          if (result == true && mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                      ),
                      _buildSettingsItem(
                        context,
                        title: '关于软件',
                        subtitle: 'V1.0.1',
                        icon: CupertinoIcons.info,
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const AboutPage(),
                            ),
                          );
                        },
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
              // 大标题
              Positioned(
                left: 20,
                right: 60,
                top: 64,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  opacity: isCollapsed ? 0 : 1,
                  child: Text(
                    '设置',
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
              // 小标题
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
                      '设置',
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
              // 返回按钮
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

  Widget _buildSettingsItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _PressableItem(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: smoothRadius(20),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary(isDark).withValues(alpha: 0.1),
                borderRadius: smoothRadius(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary(isDark)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface(isDark),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurfaceQuaternary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.onSurfaceQuaternary(isDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressableItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableItem({required this.child, required this.onTap});

  @override
  State<_PressableItem> createState() => _PressableItemState();
}

class _PressableItemState extends State<_PressableItem> {
  bool _isPressed = false;

  void _handleTap() async {
    setState(() => _isPressed = true);
    await Future.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() => _isPressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {},
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
