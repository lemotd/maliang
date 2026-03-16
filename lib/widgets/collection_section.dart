import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';
import '../models/memory_item.dart';
import '../utils/scroll_edge_haptic.dart';
import 'bill_card.dart';
import 'clothing_card.dart';
import 'add_collection_card.dart';
import '../pages/bill_summary_page.dart';
import '../pages/wardrobe_page.dart';

class CollectionSection extends StatefulWidget {
  final List<MemoryItem> memories;

  const CollectionSection({super.key, required this.memories});

  @override
  State<CollectionSection> createState() => _CollectionSectionState();
}

class _CollectionSectionState extends State<CollectionSection> {
  bool _isBillCardPressed = false;
  bool _isClothingCardPressed = false;
  bool _isAddCardPressed = false;

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
          child: ScrollEdgeHaptic(
            axis: Axis.horizontal,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                GestureDetector(
                  onTapDown: (_) {
                    setState(() => _isBillCardPressed = true);
                  },
                  onTapUp: (_) async {
                    await Future.delayed(const Duration(milliseconds: 150));
                    if (mounted) {
                      setState(() => _isBillCardPressed = false);
                    }
                  },
                  onTapCancel: () {
                    setState(() => _isBillCardPressed = false);
                  },
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) =>
                            BillSummaryPage(bills: widget.memories),
                      ),
                    );
                  },
                  child: AnimatedScale(
                    scale: _isBillCardPressed ? 0.95 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: BillCard(bills: widget.memories),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTapDown: (_) {
                    setState(() => _isClothingCardPressed = true);
                  },
                  onTapUp: (_) async {
                    await Future.delayed(const Duration(milliseconds: 150));
                    if (mounted) {
                      setState(() => _isClothingCardPressed = false);
                    }
                  },
                  onTapCancel: () {
                    setState(() => _isClothingCardPressed = false);
                  },
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) =>
                            WardrobePage(clothes: widget.memories),
                      ),
                    );
                  },
                  child: AnimatedScale(
                    scale: _isClothingCardPressed ? 0.95 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: ClothingCard(clothes: widget.memories),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTapUp: (_) async {
                    await Future.delayed(const Duration(milliseconds: 150));
                    if (mounted) {
                      setState(() => _isAddCardPressed = false);
                    }
                  },
                  onTapCancel: () {
                    setState(() => _isAddCardPressed = false);
                  },
                  onTap: () {
                    // TODO: 新建合集功能
                  },
                  child: AnimatedScale(
                    scale: _isAddCardPressed ? 0.95 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    child: const AddCollectionCard(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
