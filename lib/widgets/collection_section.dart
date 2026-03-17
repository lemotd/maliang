import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/memory_item.dart';
import '../models/collection_item.dart';
import '../services/collection_service.dart';
import '../utils/scroll_edge_haptic.dart';
import 'bill_card.dart';
import 'clothing_card.dart';
import 'add_collection_card.dart';
import 'collection_card.dart';
import 'create_collection_sheet.dart';
import 'responsive_layout.dart';
import '../pages/bill_summary_page.dart';
import '../pages/wardrobe_page.dart';
import '../pages/collection_detail_page.dart';

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
  final Set<String> _pressedCollectionIds = {};
  final CollectionService _collectionService = CollectionService();
  List<CollectionItem> _collections = [];

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  @override
  void didUpdateWidget(covariant CollectionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final collections = await _collectionService.getAllCollections();
    if (mounted) setState(() => _collections = collections);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 160,
          child: ScrollEdgeHaptic(
            axis: Axis.horizontal,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                // 账单卡片
                _buildPressable(
                  pressed: _isBillCardPressed,
                  onPressStart: () => setState(() => _isBillCardPressed = true),
                  onPressEnd: () => setState(() => _isBillCardPressed = false),
                  onTap: () async {
                    setState(() => _isBillCardPressed = true);
                    await Future.delayed(const Duration(milliseconds: 80));
                    if (mounted) setState(() => _isBillCardPressed = false);
                    if (!mounted) return;
                    final page = BillSummaryPage(bills: widget.memories);
                    if (!pushToDetailPane(
                      context,
                      page,
                      key: 'BillSummaryPage',
                    )) {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => page),
                      );
                    }
                  },
                  child: BillCard(bills: widget.memories),
                ),
                const SizedBox(width: 12),
                // 衣橱卡片
                _buildPressable(
                  pressed: _isClothingCardPressed,
                  onPressStart: () =>
                      setState(() => _isClothingCardPressed = true),
                  onPressEnd: () =>
                      setState(() => _isClothingCardPressed = false),
                  onTap: () async {
                    setState(() => _isClothingCardPressed = true);
                    await Future.delayed(const Duration(milliseconds: 80));
                    if (mounted) setState(() => _isClothingCardPressed = false);
                    if (!mounted) return;
                    final page = WardrobePage(clothes: widget.memories);
                    if (!pushToDetailPane(context, page, key: 'WardrobePage')) {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(builder: (_) => page),
                      );
                    }
                  },
                  child: ClothingCard(clothes: widget.memories),
                ),
                // 自定义合集卡片
                ..._collections.map((collection) {
                  final isPressed = _pressedCollectionIds.contains(
                    collection.id,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _buildPressable(
                      pressed: isPressed,
                      onPressStart: () => setState(
                        () => _pressedCollectionIds.add(collection.id),
                      ),
                      onPressEnd: () => setState(
                        () => _pressedCollectionIds.remove(collection.id),
                      ),
                      onTap: () async {
                        setState(
                          () => _pressedCollectionIds.add(collection.id),
                        );
                        await Future.delayed(const Duration(milliseconds: 80));
                        if (mounted)
                          setState(
                            () => _pressedCollectionIds.remove(collection.id),
                          );
                        if (!mounted) return;
                        final page = CollectionDetailPage(
                          collection: collection,
                          allMemories: widget.memories,
                        );
                        final key = 'Collection_${collection.id}';
                        if (!pushToDetailPane(context, page, key: key)) {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (_) => page),
                          );
                        }
                      },
                      child: CollectionCard(
                        collection: collection,
                        memories: widget.memories,
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 12),
                // 新建合集按钮
                _buildPressable(
                  pressed: _isAddCardPressed,
                  onPressStart: () => setState(() => _isAddCardPressed = true),
                  onPressEnd: () => setState(() => _isAddCardPressed = false),
                  onTap: () async {
                    setState(() => _isAddCardPressed = true);
                    await Future.delayed(const Duration(milliseconds: 80));
                    if (mounted) setState(() => _isAddCardPressed = false);
                    if (!mounted) return;
                    await CreateCollectionSheet.show(
                      context,
                      memories: widget.memories,
                      onCreated: _loadCollections,
                    );
                  },
                  child: const AddCollectionCard(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPressable({
    required bool pressed,
    required VoidCallback onPressStart,
    required VoidCallback onPressEnd,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTapDown: (_) => onPressStart(),
      onTapUp: (_) {},
      onTapCancel: () => onPressEnd(),
      onTap: onTap,
      child: AnimatedScale(
        scale: pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}
