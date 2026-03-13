import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';
import '../models/memory_item.dart';
import '../models/bill_category.dart';
import '../widgets/glass_button.dart';
import 'memory_detail_page.dart';

class BillSummaryPage extends StatefulWidget {
  final List<MemoryItem> bills;

  const BillSummaryPage({super.key, required this.bills});

  @override
  State<BillSummaryPage> createState() => _BillSummaryPageState();
}

class _BillSummaryPageState extends State<BillSummaryPage>
    with AutomaticKeepAliveClientMixin {
  bool _isHidden = false;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  bool _isAnimating = false;
  final List<GlobalKey> _monthKeys = [];
  int _activeMonthIndex = 0;
  final GlobalKey _stackKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isAnimating) return;
    setState(() {
      _scrollOffset = _scrollController.offset;
      _updateActiveMonth();
    });
  }

  void _updateActiveMonth() {
    int active = 0;
    for (int i = 1; i < _monthKeys.length; i++) {
      final key = _monthKeys[i];
      final ctx = key.currentContext;
      if (ctx != null) {
        final box = ctx.findRenderObject() as RenderBox;
        final pos = box.localToGlobal(Offset.zero);
        // 当月卡片的顶部滚到吸顶区域时，切换
        if (pos.dy <= 100) {
          active = i;
        }
      }
    }
    _activeMonthIndex = active;
  }

  /// 获取吸顶卡片的 top 值
  double _getStickyTop() {
    if (_activeMonthIndex == 0) {
      // 第一个月：从图片下方自然位置过渡到 0
      return (232 - _scrollOffset).clamp(0, double.infinity).toDouble();
    }
    // 其他月份：跟踪列表中对应月卡片的位置
    final key = _monthKeys[_activeMonthIndex];
    final ctx = key.currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox;
      // 获取相对于 Stack 父级的位置
      final stackCtx = _stackKey.currentContext;
      if (stackCtx != null) {
        final stackBox = stackCtx.findRenderObject() as RenderBox;
        final pos = box.localToGlobal(Offset.zero, ancestor: stackBox);
        // 16 是列表中月卡片的 top padding
        return pos.dy.clamp(0, double.infinity).toDouble();
      }
    }
    return 0;
  }

  /// 判断吸顶卡片是否处于悬浮状态（已钉住顶部）
  bool get _isStickyPinned {
    if (_activeMonthIndex == 0) {
      return _scrollOffset > 232;
    }
    return _getStickyTop() <= 0;
  }

  void _onScrollEnd() {
    if (_isAnimating) return;

    // 图片区域高度 (200 + 16*2 padding = 232)
    const double imageAreaHeight = 232.0;
    const double snapStart = 50.0;

    if (_scrollOffset > snapStart && _scrollOffset < imageAreaHeight) {
      _isAnimating = true;
      _scrollController
          .animateTo(
            imageAreaHeight,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          )
          .then((_) {
            _isAnimating = false;
          });
    }
  }

  int get _billDays {
    if (widget.bills.isEmpty) return 0;
    final billItems = widget.bills
        .where((item) => item.category == MemoryCategory.bill)
        .toList();
    if (billItems.isEmpty) return 0;

    final sortedBills = billItems
      ..sort((a, b) {
        final aDate = a.billTime ?? a.createdAt;
        final bDate = b.billTime ?? b.createdAt;
        return aDate.compareTo(bDate);
      });

    final firstBillDate =
        sortedBills.first.billTime ?? sortedBills.first.createdAt;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DateTime(
      firstBillDate.year,
      firstBillDate.month,
      firstBillDate.day,
    );

    return today.difference(firstDay).inDays + 1;
  }

  List<_MonthData> get _allMonthlyData {
    final allBills = widget.bills
        .where((bill) => bill.category == MemoryCategory.bill)
        .toList();
    final Map<String, List<MemoryItem>> byMonth = {};
    for (final bill in allBills) {
      final d = bill.billTime ?? bill.createdAt;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      byMonth.putIfAbsent(key, () => []).add(bill);
    }
    final months =
        byMonth.entries.map((entry) {
          final bills = entry.value;
          final d = bills.first.billTime ?? bills.first.createdAt;
          double expense = 0, income = 0;
          for (final bill in bills) {
            final v =
                double.tryParse(
                  (bill.amount ?? '0').replaceAll(RegExp(r'[^\d.]'), ''),
                ) ??
                0;
            if (bill.isExpense ?? true) {
              expense += v;
            } else {
              income += v;
            }
          }
          final Map<DateTime, List<MemoryItem>> byDate = {};
          for (final bill in bills) {
            final bd = bill.billTime ?? bill.createdAt;
            final dateKey = DateTime(bd.year, bd.month, bd.day);
            byDate.putIfAbsent(dateKey, () => []).add(bill);
          }
          final sortedKeys = byDate.keys.toList()
            ..sort((a, b) => b.compareTo(a));
          return _MonthData(
            year: d.year,
            month: d.month,
            expense: expense,
            income: income,
            billsByDate: Map.fromEntries(
              sortedKeys.map((k) => MapEntry(k, byDate[k]!)),
            ),
          );
        }).toList()..sort((a, b) {
          final c = b.year.compareTo(a.year);
          return c != 0 ? c : b.month.compareTo(a.month);
        });
    return months;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCollapsed = _scrollOffset > 50;
    final monthlyData = _allMonthlyData;
    // 确保 keys 数量匹配
    while (_monthKeys.length < monthlyData.length) {
      _monthKeys.add(GlobalKey());
    }
    final activeMonth = monthlyData.isNotEmpty
        ? monthlyData[_activeMonthIndex.clamp(0, monthlyData.length - 1)]
        : null;
    final firstMonth = monthlyData.isNotEmpty ? monthlyData.first : null;
    final restMonths = monthlyData.length > 1
        ? monthlyData.sublist(1)
        : <_MonthData>[];

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.surfaceLow(isDark)
          : const Color(0xFFEDEFF2),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 285,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF3482FF).withOpacity(0.1),
                      const Color(0xFF3482FF).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(isDark, isCollapsed),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollEndNotification) {
                        _onScrollEnd();
                      }
                      return false;
                    },
                    child: Stack(
                      key: _stackKey,
                      clipBehavior: Clip.none,
                      children: [
                        CustomScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          slivers: [
                            // 装饰图区域
                            SliverToBoxAdapter(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeOut,
                                opacity: isCollapsed ? 0 : 1,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    16,
                                  ),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/bill_top_picture.png',
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (monthlyData.isEmpty)
                              SliverToBoxAdapter(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 32),
                                    child: Text(
                                      '暂无账单',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppColors.onSurfaceQuaternary(isDark),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (monthlyData.isNotEmpty) ...[
                            // 第一个月卡片占位
                            SliverToBoxAdapter(
                              child: Padding(
                                key: _monthKeys[0],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: const SizedBox(height: 80),
                              ),
                            ),
                            // 第一个月的日卡片
                            if (firstMonth != null)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  0,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildListDelegate([
                                    ...firstMonth.billsByDate.entries.map((
                                      entry,
                                    ) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _buildDayCard(
                                          entry.key,
                                          entry.value,
                                          isDark,
                                        ),
                                      );
                                    }),
                                  ]),
                                ),
                              ),
                            // 其余月份：月卡片 + 日卡片
                            ...restMonths.asMap().entries.expand((monthEntry) {
                              final monthIdx =
                                  monthEntry.key +
                                  1; // +1 because first month is index 0
                              final monthData = monthEntry.value;
                              return [
                                SliverToBoxAdapter(
                                  child: Padding(
                                    key: _monthKeys[monthIdx],
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      0,
                                    ),
                                    child: Opacity(
                                      opacity: _activeMonthIndex == monthIdx
                                          ? 0
                                          : 1,
                                      child: _buildMonthCard(
                                        isDark,
                                        year: monthData.year,
                                        month: monthData.month,
                                        expense: monthData.expense,
                                        income: monthData.income,
                                      ),
                                    ),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    0,
                                  ),
                                  sliver: SliverList(
                                    delegate: SliverChildListDelegate([
                                      ...monthData.billsByDate.entries.map((
                                        entry,
                                      ) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: _buildDayCard(
                                            entry.key,
                                            entry.value,
                                            isDark,
                                          ),
                                        );
                                      }),
                                    ]),
                                  ),
                                ),
                              ];
                            }),
                            ],
                            // 底部留白（含安全区）
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height:
                                    16 + MediaQuery.of(context).padding.bottom,
                              ),
                            ),
                          ],
                        ),
                        // 吸顶月卡片 - 显示当前活跃月份，连贯过渡
                        if (activeMonth != null && monthlyData.isNotEmpty)
                          Positioned(
                            top: _getStickyTop(),
                            left: 16,
                            right: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: _isStickyPinned
                                    ? const BorderRadius.only(
                                        bottomLeft: Radius.circular(20),
                                        bottomRight: Radius.circular(20),
                                      )
                                    : BorderRadius.circular(20),
                                boxShadow: _isStickyPinned
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.06,
                                          ),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: _buildMonthCard(
                                isDark,
                                year: activeMonth.year,
                                month: activeMonth.month,
                                expense: activeMonth.expense,
                                income: activeMonth.income,
                                pinned: _isStickyPinned,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark, bool isCollapsed) {
    return Container(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: isCollapsed ? 56 : 130,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 20,
                  right: 20,
                  top: 64,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    opacity: isCollapsed ? 0 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '总账单',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF1A1A1A),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '已记账 $_billDays 天',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF8E8E93),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    opacity: isCollapsed ? 1 : 0,
                    child: SizedBox(
                      height: 56,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '总账单',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xFF1A1A1A),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 0,
                  child: GlassButton(
                    icon: CupertinoIcons.back,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            height: isCollapsed ? 0.6 : 0,
            child: Container(height: 0.6, color: const Color(0x0F000000)),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCard(
    bool isDark, {
    required int year,
    required int month,
    required double expense,
    required double income,
    bool pinned = false,
  }) {
    final radius = pinned
        ? const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          )
        : BorderRadius.circular(20);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(isDark),
        borderRadius: radius,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$year年',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurfaceQuaternary(isDark),
                  ),
                ),
                Text(
                  '$month月',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            VerticalDivider(
              width: 0.6,
              thickness: 0.6,
              color: AppColors.outline(isDark),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '支出',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurfaceQuaternary(isDark),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isHidden = !_isHidden;
                          });
                        },
                        child: Icon(
                          _isHidden ? Icons.visibility_off : Icons.visibility,
                          size: 14,
                          color: AppColors.onSurfaceQuaternary(isDark),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _isHidden ? '****' : '¥${expense.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: 'DINPro',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface(isDark),
                    ),
                  ),
                ],
              ),
            ),
            VerticalDivider(
              width: 0.6,
              thickness: 0.6,
              color: AppColors.outline(isDark),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '收入',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurfaceQuaternary(isDark),
                    ),
                  ),
                  Text(
                    _isHidden ? '****' : '¥${income.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: 'DINPro',
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(DateTime date, List<MemoryItem> bills, bool isDark) {
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    double dayExpense = 0;
    double dayIncome = 0;

    for (final bill in bills) {
      final amount = bill.amount ?? '0';
      final value =
          double.tryParse(amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      if (bill.isExpense ?? true) {
        dayExpense += value;
      } else {
        dayIncome += value;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(isDark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${date.month}月${date.day}日 周${weekDays[date.weekday - 1]}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceQuaternary(isDark),
                ),
              ),
              const Spacer(),
              if (dayExpense > 0)
                Text(
                  '支出 ¥${dayExpense.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'DINPro',
                    fontSize: 14,
                    color: AppColors.onSurfaceQuaternary(isDark),
                  ),
                ),
              if (dayExpense > 0 && dayIncome > 0) const SizedBox(width: 12),
              if (dayIncome > 0)
                Text(
                  '收入 ¥${dayIncome.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'DINPro',
                    fontSize: 14,
                    color: AppColors.onSurfaceQuaternary(isDark),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...bills.asMap().entries.map(
            (entry) => _buildBillItem(
              entry.value,
              isDark,
              isLast: entry.key == bills.length - 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillItem(MemoryItem bill, bool isDark, {bool isLast = false}) {
    final category = _getCategoryIcon(bill);
    final billDate = bill.billTime ?? bill.createdAt;
    final timeStr =
        '${billDate.hour.toString().padLeft(2, '0')}:${billDate.minute.toString().padLeft(2, '0')}';
    final amount = bill.amount ?? '0';
    final value =
        double.tryParse(amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    final isExpense = bill.isExpense ?? true;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: _PressableBillItem(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => MemoryDetailPage(memory: bill),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer(isDark),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                category,
                size: 18,
                color: AppColors.onSurfaceSecondary(isDark),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getCategoryLabel(bill),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    (bill.merchantName ?? bill.note) != null
                        ? '$timeStr | ${bill.merchantName ?? bill.note}'
                        : timeStr,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurfaceQuaternary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${isExpense ? "-" : "+"}¥${value.toStringAsFixed(2)}',
              style: TextStyle(
                fontFamily: 'DINPro',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(MemoryItem bill) {
    final categoryStr = bill.billCategory;
    final isExpense = bill.isExpense ?? true;

    if (isExpense) {
      final category = BillExpenseCategory.fromName(categoryStr ?? '');
      return category?.icon ?? Icons.more_horiz_outlined;
    } else {
      final category = BillIncomeCategory.fromName(categoryStr ?? '');
      return category?.icon ?? Icons.more_horiz_outlined;
    }
  }

  String _getCategoryLabel(MemoryItem bill) {
    final categoryStr = bill.billCategory;
    final isExpense = bill.isExpense ?? true;

    if (isExpense) {
      final category = BillExpenseCategory.fromName(categoryStr ?? '');
      return category?.label ?? (isExpense ? '其他' : '其他');
    } else {
      final category = BillIncomeCategory.fromName(categoryStr ?? '');
      return category?.label ?? (isExpense ? '其他' : '其他');
    }
  }
}

class _MonthData {
  final int year;
  final int month;
  final double expense;
  final double income;
  final Map<DateTime, List<MemoryItem>> billsByDate;

  _MonthData({
    required this.year,
    required this.month,
    required this.expense,
    required this.income,
    required this.billsByDate,
  });
}

class _PressableBillItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableBillItem({required this.child, required this.onTap});

  @override
  State<_PressableBillItem> createState() => _PressableBillItemState();
}

class _PressableBillItemState extends State<_PressableBillItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
