import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import '../models/memory_item.dart';

class SwipeableMemoryItem extends StatefulWidget {
  final MemoryItem memory;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleComplete;

  const SwipeableMemoryItem({
    super.key,
    required this.memory,
    this.onTap,
    this.onDelete,
    this.onToggleComplete,
  });

  static _SwipeableMemoryItemState? _openedState;

  static void closeAll() {
    if (_openedState != null && _openedState!.mounted) {
      _openedState!._animateReset();
    }
    _openedState = null;
  }

  @override
  State<SwipeableMemoryItem> createState() => _SwipeableMemoryItemState();
}

class _SwipeableMemoryItemState extends State<SwipeableMemoryItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;
  double _dragExtent = 0;
  static const double _stage1Threshold = 60;
  bool _isDragging = false;

  // 缓存图片
  ImageProvider? _cachedImage;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resetAnimation =
        Tween<double>(begin: 0, end: 0).animate(
          CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
        )..addListener(() {
          if (!_isDragging) {
            setState(() {
              _dragExtent = _resetAnimation.value;
            });
          }
        });
    _loadImage();
  }

  @override
  void didUpdateWidget(SwipeableMemoryItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memory.thumbnailPath != widget.memory.thumbnailPath ||
        oldWidget.memory.imagePath != widget.memory.imagePath) {
      _loadImage();
    }
  }

  void _loadImage() {
    final path = widget.memory.thumbnailPath ?? widget.memory.imagePath;
    if (path != null) {
      _cachedImage = FileImage(File(path));
    }
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _resetController.stop();
    if (SwipeableMemoryItem._openedState != null &&
        SwipeableMemoryItem._openedState != this) {
      SwipeableMemoryItem.closeAll();
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final halfScreen = screenWidth * 0.5;
    final absDrag = _dragExtent.abs();

    if (absDrag > halfScreen) {
      if (_dragExtent > 0) {
        widget.onToggleComplete?.call();
      } else {
        widget.onDelete?.call();
      }
      _animateReset();
    } else if (absDrag > _stage1Threshold) {
      _animateToHoldPosition();
      SwipeableMemoryItem._openedState = this;
    } else {
      _animateReset();
    }
  }

  void _animateToHoldPosition() {
    final targetExtent = _dragExtent > 0
        ? _stage1Threshold + 10.0
        : -(_stage1Threshold + 10.0);
    _resetAnimation = Tween<double>(begin: _dragExtent, end: targetExtent)
        .animate(
          CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
        );
    _resetController.forward(from: 0);
  }

  void _animateReset() {
    if (SwipeableMemoryItem._openedState == this) {
      SwipeableMemoryItem._openedState = null;
    }
    _resetAnimation = Tween<double>(begin: _dragExtent, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.delta.dx;
    final screenWidth = MediaQuery.of(context).size.width;
    final halfScreen = screenWidth * 0.5;
    final absDrag = _dragExtent.abs();

    double resistance;
    if (absDrag < _stage1Threshold) {
      resistance = 1.0;
    } else if (absDrag < halfScreen) {
      resistance = 0.7;
    } else {
      resistance = 0.3;
    }

    setState(() {
      _dragExtent += delta * resistance;
      _dragExtent = _dragExtent.clamp(-(halfScreen + 50), halfScreen + 50);
    });
  }

  void _onRightPillTap() {
    widget.onToggleComplete?.call();
    _animateReset();
  }

  void _onLeftPillTap() {
    widget.onDelete?.call();
    _animateReset();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }

  String _getDisplayTitle() {
    var title = widget.memory.title;
    final categoryLabel = widget.memory.category.label;

    final prefixes = [
      '$categoryLabel：',
      '$categoryLabel:',
      '取餐码：',
      '取餐码:',
      '取件码：',
      '取件码:',
      '消费 ',
      '支出 ',
      '收入 ',
    ];

    for (final prefix in prefixes) {
      if (title.startsWith(prefix)) {
        title = title.substring(prefix.length);
        break;
      }
    }

    if (widget.memory.category == MemoryCategory.bill) {
      if (!title.startsWith('-') && !title.startsWith('+')) {
        title = '-$title';
      }
    }

    return title;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final halfScreen = screenWidth * 0.5;
    final isStage2 = _dragExtent.abs() > halfScreen;
    final isRightSwipe = _dragExtent > 0;
    final isLeftSwipe = _dragExtent < 0;

    final isCompleted = widget.memory.isCompleted;
    final rightActionColor = isCompleted
        ? const Color(0xFFFF9500)
        : const Color(0xFF34C759);
    final rightActionText = isCompleted ? '待办' : '完成';
    final rightActionIcon = isCompleted
        ? CupertinoIcons.arrow_2_circlepath
        : CupertinoIcons.check_mark_circled;

    const leftActionColor = Color(0xFFFF3B30);
    const leftActionText = '删除';
    const leftActionIcon = CupertinoIcons.trash;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (isRightSwipe)
          Positioned(
            left: 16,
            top: 6,
            bottom: 6,
            width: _dragExtent - 8,
            child: RepaintBoundary(
              child: _buildActionButton(
                isStage2: isStage2,
                actionColor: rightActionColor,
                actionText: rightActionText,
                actionIcon: rightActionIcon,
                onTap: _onRightPillTap,
                dragExtent: _dragExtent,
              ),
            ),
          ),
        if (isLeftSwipe)
          Positioned(
            right: 16,
            top: 6,
            bottom: 6,
            width: _dragExtent.abs() - 8,
            child: RepaintBoundary(
              child: _buildActionButton(
                isStage2: isStage2,
                actionColor: leftActionColor,
                actionText: leftActionText,
                actionIcon: leftActionIcon,
                onTap: _onLeftPillTap,
                dragExtent: _dragExtent.abs(),
              ),
            ),
          ),
        GestureDetector(
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          onTap: () {
            SwipeableMemoryItem.closeAll();
            widget.onTap?.call();
          },
          child: Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: RepaintBoundary(child: _buildContent()),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required bool isStage2,
    required Color actionColor,
    required String actionText,
    required IconData actionIcon,
    required VoidCallback? onTap,
    required double dragExtent,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final halfScreen = screenWidth * 0.5;
    final buttonWidth = _calculateButtonWidth(dragExtent: dragExtent);
    final iconOpacity = _calculateIconOpacity(dragExtent: dragExtent);
    final iconScale = _calculateIconScale(dragExtent: dragExtent);

    // 文字透明度：进入二阶段立刻开始渐显
    final textOpacity = isStage2 ? 1.0 : 0.0;

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: buttonWidth,
          height: 40,
          decoration: BoxDecoration(
            color: actionColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                children: [
                  // 文字（带渐变动画）
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    right: 30,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedOpacity(
                        opacity: textOpacity,
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          actionText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 图标（带动画）
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 150),
                    alignment: isStage2
                        ? Alignment.centerRight
                        : Alignment.center,
                    child: Opacity(
                      opacity: iconOpacity,
                      child: Transform.scale(
                        scale: iconScale,
                        child: Icon(actionIcon, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _calculateButtonWidth({required double dragExtent}) {
    if (dragExtent <= _stage1Threshold) {
      final progress = (dragExtent / _stage1Threshold).clamp(0.0, 1.0);
      return 52 * progress;
    } else {
      return dragExtent.clamp(52.0, 200.0);
    }
  }

  double _calculateIconOpacity({required double dragExtent}) {
    if (dragExtent >= _stage1Threshold) {
      return 1.0;
    }
    final progress = (dragExtent / _stage1Threshold).clamp(0.0, 1.0);
    return progress;
  }

  double _calculateIconScale({required double dragExtent}) {
    if (dragExtent >= _stage1Threshold) {
      return 1.0;
    }
    final progress = (dragExtent / _stage1Threshold).clamp(0.0, 1.0);
    return 0.5 + progress * 0.5;
  }

  Widget _buildContent() {
    final isCompleted = widget.memory.isCompleted;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final textColor = isCompleted
        ? const Color(0xFF8E8E93)
        : (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A));
    final subTextColor = isCompleted
        ? const Color(0xFFC7C7CC)
        : const Color(0xFF8E8E93);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          _buildThumbnail(isCompleted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDisplayTitle(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? (isDark
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFFE5E5EA))
                            : widget.memory.category.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.memory.category.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted
                              ? const Color(0xFF8E8E93)
                              : widget.memory.category.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(widget.memory.createdAt),
                      style: TextStyle(fontSize: 12, color: subTextColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            color: isCompleted
                ? (isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA))
                : const Color(0xFFC7C7CC),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(bool isCompleted) {
    if (_cachedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColorFiltered(
          colorFilter: isCompleted
              ? const ColorFilter.matrix(<double>[
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  0.5,
                  0,
                ])
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: Image(
            image: _cachedImage!,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholderIcon(isCompleted),
          ),
        ),
      );
    }
    return _buildPlaceholderIcon(isCompleted);
  }

  Widget _buildPlaceholderIcon(bool isCompleted) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _getCategoryIcon(),
        color: isCompleted
            ? const Color(0xFFC7C7CC)
            : widget.memory.category.color,
        size: 28,
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (widget.memory.category) {
      case MemoryCategory.pickupCode:
        return CupertinoIcons.cube_box;
      case MemoryCategory.packageCode:
        return CupertinoIcons.cube;
      case MemoryCategory.bill:
        return CupertinoIcons.doc_text;
      case MemoryCategory.note:
        return CupertinoIcons.square_pencil;
    }
  }
}
