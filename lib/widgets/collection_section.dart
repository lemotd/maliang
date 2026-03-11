import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/memory_item.dart';
import 'bill_card.dart';
import 'add_collection_card.dart';

class CollectionSection extends StatelessWidget {
  final List<MemoryItem> memories;

  const CollectionSection({super.key, required this.memories});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '合集',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface(isDark),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            children: [
              BillCard(bills: memories),
              const SizedBox(width: 12),
              AddCollectionCard(
                onTap: () {
                  // TODO: 新建合集功能
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
