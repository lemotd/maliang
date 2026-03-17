import 'dart:io';
import 'package:flutter/material.dart';
import 'package:figma_squircle/figma_squircle.dart';
import '../theme/app_colors.dart';
import '../models/collection_item.dart';
import '../models/memory_item.dart';
import '../utils/smooth_radius.dart';

class CollectionCard extends StatelessWidget {
  final CollectionItem collection;
  final List<MemoryItem> memories;

  const CollectionCard({
    super.key,
    required this.collection,
    required this.memories,
  });

  List<MemoryItem> get _items {
    final idSet = collection.memoryIds.toSet();
    return memories.where((m) => idSet.contains(m.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _items;
    final withImage = items.where((m) => m.imagePath != null).take(4).toList();

    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(isDark),
        borderRadius: smoothRadius(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              collection.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface(isDark),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              '${items.length}条记忆',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.onSurfaceQuaternary(isDark),
              ),
            ),
            const Spacer(),
            if (withImage.isNotEmpty)
              Row(
                children: withImage.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ClipSmoothRect(
                      radius: smoothRadius(6),
                      child: Image.file(
                        File(item.imagePath!),
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              Icon(
                Icons.collections_bookmark_outlined,
                size: 32,
                color: AppColors.onSurfaceOctonary(isDark),
              ),
          ],
        ),
      ),
    );
  }
}
