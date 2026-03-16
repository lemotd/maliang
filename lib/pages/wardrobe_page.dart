import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../models/memory_item.dart';
import '../widgets/glass_button.dart';
import '../widgets/ai_glow_border.dart';
import '../widgets/ai_chat_sheet.dart';
import '../services/ai_service.dart';
import '../services/weather_service.dart';
import '../utils/scroll_edge_haptic.dart';
import 'memory_detail_page.dart';

class WardrobePage extends StatefulWidget {
  final List<MemoryItem> clothes;
  const WardrobePage({super.key, required this.clothes});
  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  late List<MemoryItem> _clothes;

  // AI 穿搭建议
  final AiService _aiService = AiService();
  final WeatherService _weatherService = WeatherService();
  String? _aiSuggestion;
  bool _isLoadingSuggestion = false;
  List<MemoryItem> _recommendedItems = [];

  @override
  void initState() {
    super.initState();
    _clothes =
        widget.clothes
            .where((m) => m.category == MemoryCategory.clothing)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });
    _generateAiSuggestion();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _generateAiSuggestion() async {
    if (_clothes.isEmpty) return;
    setState(() {
      _isLoadingSuggestion = true;
      _aiSuggestion = '';
    });

    try {
      // 获取天气
      final weather = await _weatherService.getCurrentWeather();
      final weatherStr = weather?.summary ?? '无法获取天气信息';

      // 构建衣橱摘要
      final clothesSummary = _clothes
          .take(20)
          .map((c) {
            final parts = <String>[];
            if (c.clothingName != null) parts.add(c.clothingName!);
            if (c.clothingType != null) parts.add('(${c.clothingType})');
            if (c.clothingColors.isNotEmpty)
              parts.add('颜色:${c.clothingColors.join(",")}');
            if (c.clothingSeasons.isNotEmpty)
              parts.add('季节:${c.clothingSeasons.join(",")}');
            return '- ${parts.join(" ")}';
          })
          .join('\n');

      final now = DateTime.now();
      final prompt =
          '''你是一个时尚穿搭顾问。请根据用户的衣橱内容和当前天气，给出简短的穿搭建议（60-100字）。

当前时间：${now.year}年${now.month}月${now.day}日
当前天气：$weatherStr

用户衣橱（共${_clothes.length}件）：
$clothesSummary

要求：
1. 语气亲和自然，像朋友聊天一样
2. 根据天气推荐具体的搭配方案，尽量引用衣橱中已有的衣服
3. 如果推荐了具体衣服，请在回复末尾用【推荐：衣服名称1, 衣服名称2】的格式列出（名称必须和衣橱中的完全一致）
4. 只返回建议文字，不要加标题或前缀''';

      await for (final token in _aiService.chatStream(prompt)) {
        if (!mounted) return;
        setState(() {
          _aiSuggestion = (_aiSuggestion ?? '') + token;
        });
      }

      if (mounted) {
        // 解析推荐的衣服
        _parseRecommendedItems();
        setState(() => _isLoadingSuggestion = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSuggestion = false);
    }
  }

  void _parseRecommendedItems() {
    final text = _aiSuggestion ?? '';
    final match = RegExp(r'【推荐[：:](.+?)】').firstMatch(text);
    if (match != null) {
      final names = match
          .group(1)!
          .split(RegExp(r'[,，、]'))
          .map((s) => s.trim())
          .toList();
      _recommendedItems = [];
      for (final name in names) {
        final item = _clothes.firstWhere(
          (c) => c.clothingName == name,
          orElse: () => _clothes.firstWhere(
            (c) => c.clothingName != null && c.clothingName!.contains(name),
            orElse: () => MemoryItem(
              id: '',
              title: '',
              category: MemoryCategory.clothing,
              createdAt: DateTime.now(),
            ),
          ),
        );
        if (item.id.isNotEmpty) _recommendedItems.add(item);
      }
      // 去掉文本中的推荐标记
      _aiSuggestion = text.replaceAll(RegExp(r'【推荐[：:].+?】'), '').trim();
    }
  }

  String get _displaySuggestion => _aiSuggestion ?? '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCollapsed = _scrollOffset > 50;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.surfaceLow(isDark)
          : const Color(0xFFEDEFF2),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 285,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF3482FF).withValues(alpha: 0.1),
                      const Color(0xFF3482FF).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(isDark, isCollapsed),
                Expanded(
                  child: ScrollEdgeHaptic(
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        // 装饰图
                        SliverToBoxAdapter(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            opacity: isCollapsed ? 0 : 1,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                16,
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/clothes_picture.png',
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // AI 穿搭建议卡片
                        if (_isLoadingSuggestion ||
                            (_aiSuggestion != null &&
                                _aiSuggestion!.isNotEmpty))
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: _buildAiCard(isDark),
                            ),
                          ),
                        // 宫格列表
                        if (_clothes.isEmpty)
                          SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 32),
                                child: Text(
                                  '暂无衣服',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.onSurfaceQuaternary(
                                      isDark,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16 + MediaQuery.of(context).padding.bottom,
                            ),
                            sliver: SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 1.0,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) =>
                                    _buildGridItem(_clothes[index], isDark),
                                childCount: _clothes.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiCard(bool isDark) {
    if (_isLoadingSuggestion &&
        (_aiSuggestion == null || _aiSuggestion!.isEmpty)) {
      return AIGlowBorder(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh(isDark),
            borderRadius: BorderRadius.circular(20),
          ),
          child: _AiShimmer(isDark: isDark),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(isDark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _displaySuggestion,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.onSurface(isDark),
              height: 1.5,
            ),
          ),
          // 推荐衣服缩略图
          if (_recommendedItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recommendedItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = _recommendedItems[index];
                  return _PressableGridItem(
                    onTap: () async {
                      final result =
                          await Navigator.of(
                            context,
                            rootNavigator: true,
                          ).push<MemoryItem>(
                            CupertinoPageRoute(
                              builder: (_) => MemoryDetailPage(memory: item),
                            ),
                          );
                      if (result != null) {
                        final idx = _clothes.indexWhere(
                          (c) => c.id == result.id,
                        );
                        if (idx != -1) setState(() => _clothes[idx] = result);
                      }
                    },
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer(isDark),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: item.imagePath != null
                          ? Image.file(File(item.imagePath!), fit: BoxFit.cover)
                          : Center(
                              child: Icon(
                                Icons.checkroom_outlined,
                                size: 24,
                                color: AppColors.onSurfaceOctonary(isDark),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: _AskAiButton(
              isDark: isDark,
              onTap: () => AiChatSheet.show(context, _clothes),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(MemoryItem item, bool isDark) {
    return _PressableGridItem(
      onTap: () async {
        final result = await Navigator.of(context, rootNavigator: true)
            .push<MemoryItem>(
              CupertinoPageRoute(
                builder: (context) => MemoryDetailPage(memory: item),
              ),
            );
        if (result != null) {
          final idx = _clothes.indexWhere((c) => c.id == result.id);
          if (idx != -1) setState(() => _clothes[idx] = result);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh(isDark),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: item.imagePath != null
            ? Image.file(File(item.imagePath!), fit: BoxFit.cover)
            : Center(
                child: Icon(
                  Icons.checkroom_outlined,
                  size: 28,
                  color: AppColors.onSurfaceOctonary(isDark),
                ),
              ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark, bool isCollapsed) {
    return Container(
      color: Colors.transparent,
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
                  right: 20,
                  top: 64,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    opacity: isCollapsed ? 0 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '我的衣橱',
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
                          '${_clothes.length}件衣服',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF8E8E93),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    opacity: isCollapsed ? 1 : 0,
                    child: SizedBox(
                      height: 56,
                      child: Center(
                        child: Text(
                          '我的衣橱',
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
      ),
    );
  }
}

class _PressableGridItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressableGridItem({required this.child, required this.onTap});
  @override
  State<_PressableGridItem> createState() => _PressableGridItemState();
}

class _PressableGridItemState extends State<_PressableGridItem> {
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

class _AiShimmer extends StatefulWidget {
  final bool isDark;
  const _AiShimmer({required this.isDark});
  @override
  State<_AiShimmer> createState() => _AiShimmerState();
}

class _AiShimmerState extends State<_AiShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _box(width: double.infinity, height: 16),
        const SizedBox(height: 12),
        _box(width: 200, height: 16),
      ],
    );
  }

  Widget _box({double? width, double? height}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final base = widget.isDark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFE5E5EA);
        final highlight = widget.isDark
            ? const Color(0xFF3A3A3C)
            : const Color(0xFFF2F2F5);
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Color.lerp(base, highlight, t)!,
          ),
        );
      },
    );
  }
}

class _AskAiButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _AskAiButton({required this.isDark, required this.onTap});
  @override
  State<_AskAiButton> createState() => _AskAiButtonState();
}

class _AskAiButtonState extends State<_AskAiButton> {
  bool _isPressed = false;

  void _handleTap() async {
    setState(() => _isPressed = true);
    HapticFeedback.mediumImpact();
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
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: CustomPaint(
          painter: _GradientBorderPainter(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh(widget.isDark),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                  ).createShader(bounds),
                  child: const Icon(
                    CupertinoIcons.sparkles,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '问 AI',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface(widget.isDark),
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

class _GradientBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFFEC4899), Color(0xFF06B6D4)],
      ).createShader(rect)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
