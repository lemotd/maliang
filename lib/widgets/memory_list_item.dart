import 'package:flutter/material.dart';
import 'skeleton_list_item.dart';
import 'swipeable_memory_item.dart';
import '../models/memory_item.dart';

class MemoryListItem extends StatefulWidget {
  final MemoryItem? memory;
  final bool isLoading;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleComplete;

  const MemoryListItem({
    super.key,
    this.memory,
    this.isLoading = false,
    this.onTap,
    this.onDelete,
    this.onToggleComplete,
  });

  @override
  State<MemoryListItem> createState() => _MemoryListItemState();
}

class _MemoryListItemState extends State<MemoryListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _showSkeleton = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    if (!widget.isLoading && widget.memory != null) {
      _showSkeleton = false;
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(MemoryListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      setState(() => _showSkeleton = true);
      _controller.reverse();
    } else if (!widget.isLoading && widget.memory != null && _showSkeleton) {
      setState(() => _showSkeleton = false);
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading || _showSkeleton) {
      return const SkeletonListItem();
    }

    if (widget.memory == null) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SwipeableMemoryItem(
        memory: widget.memory!,
        onTap: widget.onTap,
        onDelete: widget.onDelete,
        onToggleComplete: widget.onToggleComplete,
      ),
    );
  }
}
