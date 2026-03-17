import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';
import '../models/memory_item.dart';
import '../models/collection_item.dart';
import '../services/collection_service.dart';
import '../widgets/glass_button.dart';
import '../utils/scroll_edge_haptic.dart';
import '../utils/smooth_radius.dart';
import '../main.dart';
import 'memory_detail_page.dart';

class CollectionDetailPage extends StatefulWidget {
  final CollectionItem collection;
  final List<MemoryItem> allMemories;

  const CollectionDetailPage({
    super.key,
    required this.collection,
    required this.allMemories,
  });

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  late List<MemoryItem> _items;
  final GlobalKey _moreButtonKey = GlobalKey();
  OverlayEntry? _menuOverlay;

  @override
  void initState() {
    super.initState();
    final idSet = widget.collection.memoryIds.toSet();
    _items = widget.allMemories.where((m) => idSet.contains(m.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });
  }

  @override
  void dispose() {
    _menuOverlay?.remove();
    _menuOverlay = null;
    _scrollController.dispose();
    super.dispose();
  }

  void _showMoreMenu(bool isDark) {
    final renderBox =
        _moreButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final buttonSize = renderBox.size;
    final buttonPos = renderBox.localToGlobal(Offset.zero);
    final buttonCenter = Offset(
      buttonPos.dx + buttonSize.width / 2,
      buttonPos.dy + buttonSize.height / 2,
    );

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    void removeEntry() {
      entry.remove();
      _menuOverlay = null;
    }

    entry = OverlayEntry(
      builder: (_) => _CollectionMoreMenu(
        isDark: isDark,
        buttonCenter: buttonCenter,
        buttonSize: 40.0,
        onDelete: () {
          removeEntry();
          _showConfirmOverlay(isDark: isDark, buttonCenter: buttonCenter);
        },
        onDismiss: removeEntry,
      ),
    );

    _menuOverlay = entry;
    overlay.insert(entry);
  }

  void _showConfirmOverlay({
    required bool isDark,
    required Offset buttonCenter,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    void removeEntry() {
      entry.remove();
      _menuOverlay = null;
    }

    entry = OverlayEntry(
      builder: (_) => _CollectionConfirmMenu(
        isDark: isDark,
        buttonCenter: buttonCenter,
        buttonSize: 40.0,
        message: '确定要删除这个合集？此操作不可撤销',
        actionLabel: '删除',
        onConfirm: () {
          removeEntry();
          _deleteCollection();
        },
        onDismiss: removeEntry,
      ),
    );

    _menuOverlay = entry;
    overlay.insert(entry);
  }

  Future<void> _deleteCollection() async {
    await CollectionService().deleteCollection(widget.collection.id);
    HomePage.onDataChanged?.call();
    if (mounted) Navigator.pop(context);
  }

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
                                  'assets/Collection_picture.png',
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
                        if (widget.collection.description.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHigh(isDark),
                                  borderRadius: smoothRadius(20),
                                ),
                                child: Text(
                                  widget.collection.description,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.onSurface(isDark),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (_items.isEmpty)
                          SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 32),
                                child: Text(
                                  '暂无内容',
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
                                    _buildGridItem(_items[index], isDark),
                                childCount: _items.length,
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
          final idx = _items.indexWhere((c) => c.id == result.id);
          if (idx != -1) setState(() => _items[idx] = result);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh(isDark),
          borderRadius: smoothRadius(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: item.imagePath != null
            ? Image.file(File(item.imagePath!), fit: BoxFit.cover)
            : Center(
                child: Icon(
                  _iconForCategory(item.category),
                  size: 28,
                  color: AppColors.onSurfaceOctonary(isDark),
                ),
              ),
      ),
    );
  }

  IconData _iconForCategory(MemoryCategory cat) {
    switch (cat) {
      case MemoryCategory.bill:
        return Icons.receipt_long_outlined;
      case MemoryCategory.clothing:
        return Icons.checkroom_outlined;
      case MemoryCategory.pickupCode:
        return Icons.restaurant_menu;
      case MemoryCategory.packageCode:
        return Icons.inventory_2_outlined;
      case MemoryCategory.note:
        return Icons.note_outlined;
    }
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
                          widget.collection.name,
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
                          '${_items.length}条记忆',
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
                          widget.collection.name,
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
                    onTap: () {
                      _menuOverlay?.remove();
                      _menuOverlay = null;
                      Navigator.pop(context);
                    },
                  ),
                ),
                // 更多菜单按钮
                Positioned(
                  right: 8,
                  top: 0,
                  child: GlassButton(
                    key: _moreButtonKey,
                    icon: CupertinoIcons.ellipsis,
                    onTap: () => _showMoreMenu(isDark),
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

// ─── 毛玻璃更多菜单（仅删除项） ───

class _CollectionMoreMenu extends StatefulWidget {
  final bool isDark;
  final Offset buttonCenter;
  final double buttonSize;
  final VoidCallback onDelete;
  final VoidCallback onDismiss;

  const _CollectionMoreMenu({
    required this.isDark,
    required this.buttonCenter,
    required this.buttonSize,
    required this.onDelete,
    required this.onDismiss,
  });

  @override
  State<_CollectionMoreMenu> createState() => _CollectionMoreMenuState();
}

class _CollectionMoreMenuState extends State<_CollectionMoreMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _dismissing = false;

  static const double _menuWidth = 200.0;
  static const double _menuItemHeight = 48.0;
  static const double _menuHeight = _menuItemHeight + 20; // 一项 + 上下10px

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 280),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectItem(VoidCallback action) {
    if (_dismissing) return;
    _dismissing = true;
    _controller.reverse(from: _controller.value).then((_) {
      action();
    });
  }

  Future<void> _dismissWithAnimation() async {
    if (_dismissing) return;
    _dismissing = true;
    await _controller.reverse(from: _controller.value);
    widget.onDismiss();
  }

  double _openCurve(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    final decay = math.exp(-5.0 * t);
    return 1.0 - decay * math.cos(math.pi * 1.2 * t);
  }

  double _closeCurve(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    final smooth = t * t * (3.0 - 2.0 * t);
    final overshoot =
        math.exp(-6.0 * (1.0 - t)) * math.sin(t * math.pi * 1.8) * -0.06;
    return smooth + overshoot;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final right =
        screenWidth - (widget.buttonCenter.dx + widget.buttonSize / 2);
    final top = widget.buttonCenter.dy - widget.buttonSize / 2;

    return GestureDetector(
      onTap: () => _dismissWithAnimation(),
      behavior: HitTestBehavior.translucent,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final rawT = _controller.value;
            final isReversing = _controller.status == AnimationStatus.reverse;
            final t = isReversing ? _closeCurve(rawT) : _openCurve(rawT);

            final contentOpacity = isReversing
                ? Curves.easeIn.transform((rawT / 0.35).clamp(0.0, 1.0))
                : Curves.easeOut.transform(
                    ((rawT - 0.1) / 0.45).clamp(0.0, 1.0),
                  );

            final clampedT = t.clamp(0.0, 1.0);
            final currentWidth =
                widget.buttonSize + (_menuWidth - widget.buttonSize) * clampedT;
            final currentHeight =
                widget.buttonSize +
                (_menuHeight - widget.buttonSize) * clampedT;
            final currentRadius =
                widget.buttonSize / 2 +
                (24.0 - widget.buttonSize / 2) * clampedT;

            final overshoot = t - clampedT;
            final bounceScale = 1.0 + overshoot.abs() * 0.25;
            final shadowOpacity = clampedT;

            return Stack(
              children: [
                // 弥散阴影
                Positioned(
                  right: right - 12,
                  top: top - 6,
                  child: IgnorePointer(
                    child: Transform.scale(
                      scale: bounceScale,
                      alignment: Alignment.topRight,
                      child: Container(
                        width: currentWidth + 24,
                        height: currentHeight + 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            currentRadius + 6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (widget.isDark
                                          ? Colors.black
                                          : const Color(0xFFAEAEB2))
                                      .withOpacity(0.12 * shadowOpacity),
                              blurRadius: 60 * shadowOpacity,
                              spreadRadius: 4 * shadowOpacity,
                              offset: Offset(0, 16 * shadowOpacity),
                            ),
                            BoxShadow(
                              color:
                                  (widget.isDark
                                          ? Colors.black
                                          : const Color(0xFFAEAEB2))
                                      .withOpacity(0.08 * shadowOpacity),
                              blurRadius: 30 * shadowOpacity,
                              offset: Offset(0, 8 * shadowOpacity),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 菜单主体
                Positioned(
                  right: right,
                  top: top,
                  width: _menuWidth,
                  height: _menuHeight,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Transform.scale(
                      scale: bounceScale,
                      alignment: Alignment.topRight,
                      child: SizedBox(
                        width: currentWidth,
                        height: currentHeight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(currentRadius),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 40 * clampedT.clamp(0.1, 1.0),
                              sigmaY: 40 * clampedT.clamp(0.1, 1.0),
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: widget.isDark
                                    ? Color.lerp(
                                        const Color(
                                          0xFF2C2C2E,
                                        ).withOpacity(0.0),
                                        const Color(
                                          0xFF2C2C2E,
                                        ).withOpacity(0.85),
                                        clampedT,
                                      )
                                    : Color.lerp(
                                        Colors.white.withOpacity(0.0),
                                        Colors.white.withOpacity(0.80),
                                        clampedT,
                                      ),
                                border: Border.all(
                                  color:
                                      (widget.isDark
                                              ? const Color(0xFF3A3A3C)
                                              : Colors.white.withOpacity(0.8))
                                          .withOpacity(clampedT),
                                  width: 0.5,
                                ),
                              ),
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                maxWidth: _menuWidth,
                                maxHeight: _menuHeight,
                                child: Opacity(
                                  opacity: contentOpacity.clamp(0.0, 1.0),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            child: _CollectionMenuItem(
              icon: CupertinoIcons.trash,
              label: '删除',
              color: AppColors.warning(widget.isDark),
              isDark: widget.isDark,
              onTap: () => _selectItem(widget.onDelete),
              itemHeight: _menuItemHeight,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 确认菜单 ───

class _CollectionConfirmMenu extends StatefulWidget {
  final bool isDark;
  final Offset buttonCenter;
  final double buttonSize;
  final String message;
  final String actionLabel;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const _CollectionConfirmMenu({
    required this.isDark,
    required this.buttonCenter,
    required this.buttonSize,
    required this.message,
    required this.actionLabel,
    required this.onConfirm,
    required this.onDismiss,
  });

  @override
  State<_CollectionConfirmMenu> createState() => _CollectionConfirmMenuState();
}

class _CollectionConfirmMenuState extends State<_CollectionConfirmMenu>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pressController;
  bool _dismissing = false;
  final GlobalKey _contentKey = GlobalKey();
  double? _measuredHeight;

  static const double _menuWidth = 220.0;
  double get _menuHeight => _measuredHeight ?? 200.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 280),
    );
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 350),
    );
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureContent();
    });
  }

  void _measureContent() {
    final renderBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && _measuredHeight == null) {
      setState(() => _measuredHeight = renderBox.size.height);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _dismissWithAnimation() async {
    if (_dismissing) return;
    _dismissing = true;
    await _controller.reverse(from: _controller.value);
    widget.onDismiss();
  }

  double _openCurve(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    final decay = math.exp(-5.0 * t);
    return 1.0 - decay * math.cos(math.pi * 1.2 * t);
  }

  double _closeCurve(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    final smooth = t * t * (3.0 - 2.0 * t);
    final overshoot =
        math.exp(-6.0 * (1.0 - t)) * math.sin(t * math.pi * 1.8) * -0.06;
    return smooth + overshoot;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final right =
        screenWidth - (widget.buttonCenter.dx + widget.buttonSize / 2);
    final top = widget.buttonCenter.dy - widget.buttonSize / 2;

    return GestureDetector(
      onTap: () => _dismissWithAnimation(),
      behavior: HitTestBehavior.translucent,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final rawT = _controller.value;
            final isReversing = _controller.status == AnimationStatus.reverse;
            final t = isReversing ? _closeCurve(rawT) : _openCurve(rawT);

            final contentOpacity = isReversing
                ? Curves.easeIn.transform((rawT / 0.35).clamp(0.0, 1.0))
                : Curves.easeOut.transform(
                    ((rawT - 0.1) / 0.45).clamp(0.0, 1.0),
                  );

            final clampedT = t.clamp(0.0, 1.0);
            final currentWidth =
                widget.buttonSize + (_menuWidth - widget.buttonSize) * clampedT;
            final currentHeight =
                widget.buttonSize +
                (_menuHeight - widget.buttonSize) * clampedT;
            final currentRadius =
                widget.buttonSize / 2 +
                (24.0 - widget.buttonSize / 2) * clampedT;

            final bounceScale = 1.0 + (t - clampedT).abs() * 0.15;
            final shadowOpacity = clampedT;

            return Stack(
              children: [
                Positioned(
                  right: right - 12,
                  top: top - 6,
                  child: IgnorePointer(
                    child: Transform.scale(
                      scale: bounceScale,
                      alignment: Alignment.topRight,
                      child: Container(
                        width: currentWidth + 24,
                        height: currentHeight + 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            currentRadius + 6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (widget.isDark
                                          ? Colors.black
                                          : const Color(0xFFAEAEB2))
                                      .withOpacity(0.12 * shadowOpacity),
                              blurRadius: 60 * shadowOpacity,
                              spreadRadius: 4 * shadowOpacity,
                              offset: Offset(0, 16 * shadowOpacity),
                            ),
                            BoxShadow(
                              color:
                                  (widget.isDark
                                          ? Colors.black
                                          : const Color(0xFFAEAEB2))
                                      .withOpacity(0.08 * shadowOpacity),
                              blurRadius: 30 * shadowOpacity,
                              offset: Offset(0, 8 * shadowOpacity),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: right,
                  top: top,
                  width: _menuWidth,
                  height: _menuHeight,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTapDown: (_) => _pressController.forward(),
                      onTapUp: (_) {
                        _pressController.reverse();
                        _dismissWithAnimation();
                      },
                      onTapCancel: () => _pressController.reverse(),
                      child: AnimatedBuilder(
                        animation: _pressController,
                        builder: (context, pressChild) {
                          final pressT = Curves.easeOut.transform(
                            _pressController.value,
                          );
                          final pressScale = 1.0 + 0.06 * pressT;
                          return Transform.scale(
                            scale: bounceScale * pressScale,
                            alignment: Alignment.topRight,
                            child: pressChild,
                          );
                        },
                        child: SizedBox(
                          width: currentWidth,
                          height: currentHeight,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(currentRadius),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 40 * clampedT.clamp(0.1, 1.0),
                                sigmaY: 40 * clampedT.clamp(0.1, 1.0),
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: widget.isDark
                                      ? Color.lerp(
                                          const Color(
                                            0xFF2C2C2E,
                                          ).withOpacity(0.0),
                                          const Color(
                                            0xFF2C2C2E,
                                          ).withOpacity(0.85),
                                          clampedT,
                                        )
                                      : Color.lerp(
                                          Colors.white.withOpacity(0.0),
                                          Colors.white.withOpacity(0.80),
                                          clampedT,
                                        ),
                                  border: Border.all(
                                    color:
                                        (widget.isDark
                                                ? const Color(0xFF3A3A3C)
                                                : Colors.white.withOpacity(0.8))
                                            .withOpacity(clampedT),
                                    width: 0.5,
                                  ),
                                ),
                                child: OverflowBox(
                                  alignment: Alignment.topCenter,
                                  maxWidth: _menuWidth,
                                  maxHeight: _menuHeight,
                                  child: Opacity(
                                    opacity: contentOpacity.clamp(0.0, 1.0),
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          child: Padding(
            key: _contentKey,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface(widget.isDark),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: _ConfirmCapsuleButton(
                    label: widget.actionLabel,
                    isDark: widget.isDark,
                    onTap: () {
                      if (_dismissing) return;
                      _dismissing = true;
                      _controller.reverse(from: _controller.value).then((_) {
                        widget.onConfirm();
                      });
                    },
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

// ─── 辅助组件 ───

class _ConfirmCapsuleButton extends StatefulWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _ConfirmCapsuleButton({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ConfirmCapsuleButton> createState() => _ConfirmCapsuleButtonState();
}

class _ConfirmCapsuleButtonState extends State<_ConfirmCapsuleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer(widget.isDark),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.warning(widget.isDark),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  final double itemHeight;

  const _CollectionMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
    required this.itemHeight,
  });

  @override
  State<_CollectionMenuItem> createState() => _CollectionMenuItemState();
}

class _CollectionMenuItemState extends State<_CollectionMenuItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: widget.itemHeight,
        decoration: BoxDecoration(
          color: _pressed
              ? (widget.isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Icon(widget.icon, size: 20, color: widget.color),
            const SizedBox(width: 12),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: widget.color,
              ),
            ),
          ],
        ),
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
