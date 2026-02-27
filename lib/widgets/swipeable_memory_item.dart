import 'package:flutter/material.dart';
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

  @override
  State<SwipeableMemoryItem> createState() => _SwipeableMemoryItemState();
}

class _SwipeableMemoryItemState extends State<SwipeableMemoryItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;
  double _dragExtent = 0;
  static const double _actionThreshold = 80;
  static const double _maxDragExtent = 140;
  bool _isDragging = false;

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
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _resetController.stop();
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;

    if (_dragExtent > _actionThreshold) {
      widget.onToggleComplete?.call();
    }

    _animateReset();
  }

  void _animateReset() {
    _resetAnimation = Tween<double>(begin: _dragExtent, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.delta.dx;
    final resistance = _dragExtent > _actionThreshold ? 0.4 : 1.0;

    setState(() {
      _dragExtent += delta * resistance;
      _dragExtent = _dragExtent.clamp(0.0, _maxDragExtent);
    });
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

  @override
  Widget build(BuildContext context) {
    final showComplete = _dragExtent > 0;
    final isCompleted = widget.memory.isCompleted;
    final actionColor = isCompleted
        ? const Color(0xFFFF9500)
        : const Color(0xFF34C759);
    final actionText = isCompleted ? '待办' : '完成';
    final progress = (_dragExtent / _actionThreshold).clamp(0.0, 1.0);
    final showText = _dragExtent > 100;

    return Stack(
      children: [
        if (showComplete)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Color.lerp(
                  actionColor.withOpacity(0.15),
                  actionColor,
                  progress,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: _dragExtent,
                  child: Center(
                    child: Icon(
                      isCompleted ? Icons.replay : Icons.check_circle_outline,
                      color: Color.lerp(actionColor, Colors.white, progress),
                      size: 24 + progress * 4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (showComplete && showText)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: actionColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: _dragExtent,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCompleted
                              ? Icons.replay
                              : Icons.check_circle_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          actionText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        GestureDetector(
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          onTap: widget.onTap,
          onLongPress: widget.onDelete,
          child: Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: _buildContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final isCompleted = widget.memory.isCompleted;
    final textColor = isCompleted
        ? const Color(0xFF8E8E93)
        : const Color(0xFF1A1A1A);
    final subTextColor = isCompleted
        ? const Color(0xFFC7C7CC)
        : const Color(0xFF8E8E93);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.memory.thumbnailPath != null ||
              widget.memory.imagePath != null)
            ClipRRect(
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
                    : const ColorFilter.matrix(<double>[
                        1,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ]),
                child: Image.file(
                  File(widget.memory.thumbnailPath ?? widget.memory.imagePath!),
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: const Color(0xFFF2F2F7),
                    child: const Icon(Icons.image, color: Color(0xFFC7C7CC)),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getCategoryIcon(),
                color: isCompleted
                    ? const Color(0xFFC7C7CC)
                    : widget.memory.category.color,
                size: 28,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.memory.title,
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
                            ? const Color(0xFFE5E5EA)
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
          const Icon(Icons.chevron_right, color: Color(0xFFC7C7CC), size: 20),
        ],
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (widget.memory.category) {
      case MemoryCategory.pickupCode:
        return Icons.restaurant;
      case MemoryCategory.packageCode:
        return Icons.inventory_2;
      case MemoryCategory.bill:
        return Icons.receipt_long;
      case MemoryCategory.note:
        return Icons.note;
    }
  }
}
