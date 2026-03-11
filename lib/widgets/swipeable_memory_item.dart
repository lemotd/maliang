import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui';
import '../models/memory_item.dart';
import '../theme/app_colors.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;
  double _dragExtent = 0;
  static const double _stage1Threshold = 60;
  bool _isDragging = false;
  bool _hasTriggeredStage2Haptic = false;

  // 缓存图片
  ImageProvider? _cachedImage;
  Size? _imageSize;

  // 点击缩放状态
  bool _isPressed = false;

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
    if (oldWidget.memory.title != widget.memory.title ||
        oldWidget.memory.amount != widget.memory.amount ||
        oldWidget.memory.billCategory != widget.memory.billCategory ||
        oldWidget.memory.note != widget.memory.note) {
      setState(() {});
    }
  }

  void _loadImage() async {
    final path = widget.memory.thumbnailPath ?? widget.memory.imagePath;
    if (path != null) {
      _cachedImage = FileImage(File(path));
      // 获取图片尺寸
      try {
        final file = File(path);
        final bytes = await file.readAsBytes();
        final image = await decodeImageFromList(bytes);
        if (mounted) {
          setState(() {
            _imageSize = Size(image.width.toDouble(), image.height.toDouble());
          });
        }
      } catch (e) {
        // 忽略错误
      }
    }
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _hasTriggeredStage2Haptic = false;
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

    // 检测进入二阶段时触发振动
    final newAbsDrag = _dragExtent.abs();
    if (newAbsDrag > halfScreen && !_hasTriggeredStage2Haptic) {
      HapticFeedback.lightImpact();
      _hasTriggeredStage2Haptic = true;
    }
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
    final isToday =
        time.year == now.year && time.month == now.month && time.day == now.day;

    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (isToday) {
      return '今天 $timeStr';
    } else {
      return '${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')} $timeStr';
    }
  }

  String _getDisplayTitle() {
    final category = widget.memory.category;

    // 取餐码/取件码：直接显示取件码
    if (category == MemoryCategory.pickupCode ||
        category == MemoryCategory.packageCode) {
      // 优先使用 pickupCode 字段
      if (widget.memory.pickupCode != null &&
          widget.memory.pickupCode!.isNotEmpty) {
        return widget.memory.pickupCode!;
      }
      
      // 从 infoSections 中提取取件码
      for (final section in widget.memory.infoSections) {
        for (final item in section.items) {
            if (item.label == '取餐码' || item.label == '取件码') {
              if (item.value.isNotEmpty) {
                return item.value;
              }
            }
          }
      }
      
      // 从 title 中提取
      var title = widget.memory.title;
      final prefixes = [
        '取餐码：',
        '取餐码:',
        '取件码：',
        '取件码:',
      ];
      for (final prefix in prefixes) {
        if (title.startsWith(prefix)) {
          return title.substring(prefix.length);
        }
      }
      
      return title;
    }

    // 账单：直接显示金额
    if (category == MemoryCategory.bill) {
      if (widget.memory.amount != null && widget.memory.amount!.isNotEmpty) {
        var amount = widget.memory.amount!;
        final isExpense = widget.memory.isExpense ?? true;
        if (!amount.contains('¥')) {
          if (isExpense) {
            amount = '-¥$amount';
          } else {
            amount = '+¥$amount';
          }
        }
        return amount;
      }
      
      // 从 infoSections 中提取金额
      for (final section in widget.memory.infoSections) {
        for (final item in section.items) {
          if (item.label == '金额') {
            if (item.value.isNotEmpty) {
              var amount = item.value;
              final isExpense = widget.memory.isExpense ?? true;
              if (!amount.contains('¥')) {
                if (isExpense) {
                  amount = '-¥$amount';
                } else {
                  amount = '+¥$amount';
                }
              }
              return amount;
            }
          }
        }
      }
      
      // 从 title 中提取
      var title = widget.memory.title;
      final prefixes = [
        '账单：',
        '账单:',
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
      
      if (!title.contains('¥')) {
        if (!title.startsWith('-') && !title.startsWith('+')) {
          title = '-¥$title';
        } else if (title.startsWith('-')) {
          title = '-¥${title.substring(1)}';
        } else if (title.startsWith('+')) {
          title = '+¥${title.substring(1)}';
        }
      }
      
      return title;
    }

    // 其他情况：使用原来的逻辑
    var title = widget.memory.title;
    final categoryLabel = widget.memory.category.label;

    final prefixes = [
      '$categoryLabel：',
      '$categoryLabel:',
    ];

    for (final prefix in prefixes) {
      if (title.startsWith(prefix)) {
        title = title.substring(prefix.length);
        break;
      }
    }

    return title;
  }

  String _getSubtitle() {
    if (widget.memory.summary != null && widget.memory.summary!.isNotEmpty) {
      return widget.memory.summary!;
    }
    final detailInfo = widget.memory.getDetailInfo();
    if (detailInfo.isEmpty) {
      return '';
    }
    return detailInfo.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final halfScreen = screenWidth * 0.5;
    final isStage2 = _dragExtent.abs() > halfScreen;
    final isRightSwipe = _dragExtent > 0;
    final isLeftSwipe = _dragExtent < 0;

    final isCompleted = widget.memory.isCompleted;
    final rightActionColor = isCompleted
        ? AppColors.yellow(isDark)
        : AppColors.success(isDark);
    final rightActionText = isCompleted ? '待办' : '完成';
    final rightActionIcon = isCompleted
        ? CupertinoIcons.arrow_2_circlepath
        : CupertinoIcons.check_mark_circled;

    final leftActionColor = AppColors.warning(isDark);
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
          onTapDown: (_) {
            setState(() => _isPressed = true);
          },
          onTapUp: (_) async {
            // 确保动画至少执行100ms
            await Future.delayed(const Duration(milliseconds: 100));
            if (mounted) {
              setState(() => _isPressed = false);
            }
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
          },
          onTap: () {
            SwipeableMemoryItem.closeAll();
            widget.onTap?.call();
          },
          child: Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: AnimatedScale(
              scale: _isPressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              child: RepaintBoundary(child: _buildContent()),
            ),
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

    // 标题颜色
    final textColor = isCompleted
        ? AppColors.onSurfaceQuaternary(isDark)
        : AppColors.onSurface(isDark);
    // 副标题和时间颜色 - 已完成时更浅
    final subTextColor = isCompleted
        ? AppColors.onSurfaceOctonary(isDark)
        : AppColors.onSurfaceQuaternary(isDark);
    final subtitle = _getSubtitle();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 标题
                Text(
                  _getDisplayTitle(),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // 副标题（详细内容）- 始终留出两行高度
                const SizedBox(height: 4),
                SizedBox(
                  height: 40, // 两行文字高度 (14 * 1.4 * 2 ≈ 39)
                  child: Text(
                    subtitle.isNotEmpty ? subtitle : '',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                      color: subTextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 6),
                // 时间 + 分类
                Row(
                  children: [
                    Text(
                      _formatTime(widget.memory.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: subTextColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildCategoryTag(isCompleted),
                  ],
                ),
              ],
            ),
          ),
          // 右侧缩略图容器 - 固定宽度，居中对齐
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Center(child: _buildThumbnail(isCompleted)),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTag(bool isCompleted) {
    final category = widget.memory.category;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getCategoryIcon(category),
          size: 14,
          color: isCompleted
              ? AppColors.onSurfaceOctonary(isDark)
              : category.color,
        ),
        const SizedBox(width: 4),
        Text(
          category.label,
          style: TextStyle(
            fontSize: 12,
            color: isCompleted
                ? AppColors.onSurfaceOctonary(isDark)
                : AppColors.onSurfaceQuaternary(isDark),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(MemoryCategory category) {
    switch (category) {
      case MemoryCategory.pickupCode:
        return Icons.restaurant_menu;
      case MemoryCategory.packageCode:
        return Icons.inventory_2;
      case MemoryCategory.bill:
        return Icons.receipt_long;
      case MemoryCategory.note:
        return Icons.note_alt;
    }
  }

  Widget _buildThumbnail(bool isCompleted) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 缩略图最大尺寸
    const maxWidth = 72.0;
    const maxHeight = 72.0;

    if (_cachedImage != null && _imageSize != null) {
      // 按原比例计算缩略图尺寸
      final aspectRatio = _imageSize!.width / _imageSize!.height;
      double displayWidth;
      double displayHeight;

      if (aspectRatio > 1) {
        // 横向图片
        displayWidth = maxWidth;
        displayHeight = maxWidth / aspectRatio;
      } else {
        // 纵向图片
        displayHeight = maxHeight;
        displayWidth = maxHeight * aspectRatio;
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
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
            width: displayWidth,
            height: displayHeight,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPlaceholderIcon(isCompleted),
          ),
        ),
      );
    }
    return _buildPlaceholderIcon(isCompleted);
  }

  Widget _buildPlaceholderIcon(bool isCompleted) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer(isDark),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getCategoryIcon(widget.memory.category),
        color: isCompleted
            ? AppColors.onSurfaceOctonary(isDark)
            : widget.memory.category.color,
        size: 32,
      ),
    );
  }
}
