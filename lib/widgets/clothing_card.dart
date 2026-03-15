import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/memory_item.dart';

class ClothingCard extends StatelessWidget {
  final List<MemoryItem> clothes;

  const ClothingCard({super.key, required this.clothes});

  int get _count =>
      clothes.where((m) => m.category == MemoryCategory.clothing).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final withImage = clothes
        .where((m) => m.category == MemoryCategory.clothing && m.imagePath != null)
        .take(4)
        .toList();

    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(isDark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '我的衣橱',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface(isDark),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '$_count件衣服',
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
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
                Icons.checkroom_outlined,
                size: 32,
                color: AppColors.onSurfaceOctonary(isDark),
              ),
          ],
        ),
      ),
    );
  }
}
