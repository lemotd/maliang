import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import '../models/memory_item.dart';

class MemoryListItem extends StatelessWidget {
  final MemoryItem memory;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const MemoryListItem({
    super.key,
    required this.memory,
    this.onTap,
    this.onDelete,
  });

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
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
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
            if (memory.thumbnailPath != null || memory.imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(memory.thumbnailPath ?? memory.imagePath!),
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: const Color(0xFFF2F2F7),
                    child: const Icon(
                      CupertinoIcons.photo,
                      color: Color(0xFFC7C7CC),
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
                  color: memory.category.color,
                  size: 28,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getDisplayTitle(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
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
                          color: memory.category.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          memory.category.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: memory.category.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(memory.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: Color(0xFFC7C7CC),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (memory.category) {
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

  String _getDisplayTitle() {
    var title = memory.title;
    final categoryLabel = memory.category.label;
    
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
    
    // 为账单标题添加收支符号
    if (memory.category == MemoryCategory.bill) {
      if (!title.startsWith('-') && !title.startsWith('+')) {
        title = '-$title';
      }
    }
    
    return title;
  }
}
