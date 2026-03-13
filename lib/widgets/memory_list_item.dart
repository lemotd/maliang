import 'package:flutter/material.dart';
import 'skeleton_list_item.dart';
import 'swipeable_memory_item.dart';
import '../models/memory_item.dart';

class MemoryListItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SkeletonListItem();
    }

    if (memory == null) {
      return const SizedBox.shrink();
    }

    return SwipeableMemoryItem(
      memory: memory!,
      onTap: onTap,
      onDelete: onDelete,
      onToggleComplete: onToggleComplete,
    );
  }
}
