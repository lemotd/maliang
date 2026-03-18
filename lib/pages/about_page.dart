import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:figma_squircle/figma_squircle.dart';
import 'package:url_launcher/url_launcher.dart';
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
                                width: 90,
                                height: 90,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '马良神记',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurface(isDark),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'V1.0.1',
                              style: TextStyle(
                                fontSize: 16,

                                fontWeight: FontWeight.w400,
                                color: AppColors.onSurfaceQuaternary(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      // 当前版本更新日志卡片
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1C1C1E)
                                : Colors.white,
                            borderRadius: smoothRadius(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLogItem(isDark, '新增', '设置页支持自定义使用其他模型'),
                              const SizedBox(height: 10),
                              _buildLogItem(isDark, '新增', '备份数据支持备份 AI 模型配置文件'),
                              const SizedBox(height: 10),
                              _buildLogItem(isDark, '新增', '首页列表新增删除动画'),
                              const SizedBox(height: 10),
                              _buildLogItem(
                                isDark,
                                '新增',
                                '左右滑动首页 tab 到边界，增加触感反馈',
                              ),
                              const SizedBox(height: 10),
                              _buildLogItem(isDark, '新增', '关于我们页面改版'),
                              const SizedBox(height: 10),
                              _buildLogItem(
                                isDark,
                                '优化',
                                '图片上传逻辑，上传较大图片时不会卡在主界面',
                              ),
                              const SizedBox(height: 10),
                              _buildLogItem(isDark, '优化', '新建合集页面的动画流畅度'),
                              const SizedBox(height: 10),
                              _buildLogItem(
                                isDark,
                                '优化',
                                '取餐码和账单识别逻辑，同时存在取餐码和账单时，会分别生成两条记忆',
                              ),
                              const SizedBox(height: 10),
                              _buildLogItem(
                                isDark,
                                '优化',
                                '取件码和账单识别逻辑，同时存在取件码和账单时，会分别生成两条记忆',
                              ),
                              const SizedBox(height: 10),
                              _buildLogItem(
                                isDark,
                                '优化',
                                '多条同类型内容识别逻辑，同时存在多条同类型内容时，会分别生成多条记忆',
                              ),
                              const SizedBox(height: 10),
                              _buildLogItem(
                                isDark,
                                '修复',
                                '首页 tab 在深色模式下颜色显示异常',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 查看更多更新日志
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _PressableCard(
                          onTap: () => launchUrl(
                            Uri.parse(
                              'https://my.feishu.cn/wiki/Xd9Zwm3pXidVEVkeE3ZchZ72nKb?from=from_copylink',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1C1C1E)
                                  : Colors.white,
                              borderRadius: smoothRadius(20),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '查看更多更新日志',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.onSurface(isDark),
                                    ),
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
                        ),
                      ),
                      const SizedBox(height: 40),
                      // 补偿 AppBar 收缩高度差，防止弹回
                      const SizedBox(height: 54),
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

  Widget _buildLogItem(bool isDark, String tag, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tag,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.onSurfaceTertiary(isDark),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            content,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.onSurfaceTertiary(isDark),
            ),
          ),
        ),
      ],
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

class _PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableCard({required this.child, required this.onTap});

  @override
  State<_PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<_PressableCard> {
  bool _pressed = false;

  void _handleTap() async {
    setState(() => _pressed = true);
    await Future.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() => _pressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {},
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
