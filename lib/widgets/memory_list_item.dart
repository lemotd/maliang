import 'package:flutter/material.dart';
import 'skeleton_list_item.dart';
import 'swipeable_memory_item.dart';
import '../models/memory_item.dart';

class MemoryListItem extends StatelessWidget {
  final MemoryItem? memory;
  final bool isLoading;
  final bool isNew;
  final bool isReanalyzing;
  final VoidCallback? onTap;
  final void Function(double dragOffset)? onDelete;
  final VoidCallback? onToggleComplete;
  final VoidCallback? onAnimationComplete;

  const MemoryListItem({
    super.key,
    this.memory,
    this.isLoading = false,
    this.isNew = false,
    this.isReanalyzing = false,
    this.onTap,
    this.onDelete,
    this.onToggleComplete,
    this.onAnimationComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || isReanalyzing) {
      return const SkeletonListItem();
    }

    if (memory == null) {
      return const SizedBox.shrink();
    }

    return SwipeableMemoryItem(
      memory: memory!,
      isNew: isNew,
      onAnimationComplete: onAnimationComplete,
      onTap: onTap,
      onDelete: onDelete,
      onToggleComplete: onToggleComplete,
    );
  }
}
