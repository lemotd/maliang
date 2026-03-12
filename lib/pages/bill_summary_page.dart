import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';
import '../models/memory_item.dart';
import '../models/bill_category.dart';
import '../widgets/glass_button.dart';

class BillSummaryPage extends StatefulWidget {
  final List<MemoryItem> bills;

  const BillSummaryPage({super.key, required this.bills});

  @override
  State<BillSummaryPage> createState() => _BillSummaryPageState();
}

class _BillSummaryPageState extends State<BillSummaryPage> {
  bool _isHidden = false;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  bool _isAnimating = false;

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
    });
  }

  void _onScrollEnd() {
    if (_isAnimating) return;

    const double collapseThreshold = 50.0;
    const double snapThreshold = 100.0;

    if (_scrollOffset > collapseThreshold && _scrollOffset < snapThreshold) {
      _isAnimating = true;
      _scrollController
          .animateTo(
            snapThreshold,
            duration: const Duration(milliseconds: 200),
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

  List<MemoryItem> get _monthBills {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return widget.bills.where((bill) {
      if (bill.category != MemoryCategory.bill) return false;
      final billDate = bill.billTime ?? bill.createdAt;
      return billDate.isAfter(monthStart) ||
          billDate.isAtSameMomentAs(monthStart);
    }).toList();
  }

  double get _monthExpense {
    double total = 0;
    for (final bill in _monthBills) {
      if (bill.isExpense ?? true) {
        final amount = bill.amount ?? '0';
        final value =
            double.tryParse(amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        total += value;
      }
    }
    return total;
  }

  double get _monthIncome {
    double total = 0;
    for (final bill in _monthBills) {
      if (!(bill.isExpense ?? true)) {
        final amount = bill.amount ?? '0';
        final value =
            double.tryParse(amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        total += value;
      }
    }
    return total;
  }

  Map<DateTime, List<MemoryItem>> get _billsByDate {
    final Map<DateTime, List<MemoryItem>> result = {};
    for (final bill in _monthBills) {
      final billDate = bill.billTime ?? bill.createdAt;
      final dateKey = DateTime(billDate.year, billDate.month, billDate.day);
      result.putIfAbsent(dateKey, () => []).add(bill);
    }
    final sortedKeys = result.keys.toList()..sort((a, b) => b.compareTo(a));
    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, result[key]!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCollapsed = _scrollOffset > 50;

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
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      children: [
                        // 装饰图区域
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOut,
                          opacity: isCollapsed ? 0 : 1,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Center(
                              child: Image.asset(
                                'assets/bill_top_picture.png',
                                width: 200,
                                height: 200,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        _buildMonthCard(isDark),
                        const SizedBox(height: 16),
                        ..._billsByDate.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildDayCard(
                              entry.key,
                              entry.value,
                              isDark,
                            ),
                          );
                        }),
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

  Widget _buildMonthCard(bool isDark) {
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(isDark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer(isDark),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${now.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceQuaternary(isDark),
                  ),
                ),
                Text(
                  '${now.month}月',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface(isDark),
                  ),
                ),
              ],
            ),
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
                        fontSize: 12,
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
                  _isHidden ? '****' : '¥${_monthExpense.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface(isDark),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '收入',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceQuaternary(isDark),
                  ),
                ),
                Text(
                  _isHidden ? '****' : '¥${_monthIncome.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface(isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(isDark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${date.day}日',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface(isDark),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '周${weekDays[date.weekday - 1]}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onSurfaceQuaternary(isDark),
                ),
              ),
              const Spacer(),
              if (dayExpense > 0)
                Text(
                  '支出 ¥${dayExpense.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceQuaternary(isDark),
                  ),
                ),
              if (dayExpense > 0 && dayIncome > 0) const SizedBox(width: 12),
              if (dayIncome > 0)
                Text(
                  '收入 ¥${dayIncome.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceQuaternary(isDark),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...bills.map((bill) => _buildBillItem(bill, isDark)),
        ],
      ),
    );
  }

  Widget _buildBillItem(MemoryItem bill, bool isDark) {
    final category = _getCategoryIcon(bill);
    final billDate = bill.billTime ?? bill.createdAt;
    final timeStr =
        '${billDate.hour.toString().padLeft(2, '0')}:${billDate.minute.toString().padLeft(2, '0')}';
    final amount = bill.amount ?? '0';
    final value =
        double.tryParse(amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
    final isExpense = bill.isExpense ?? true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer(isDark),
              borderRadius: BorderRadius.circular(8),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurface(isDark),
                  ),
                ),
                Text(
                  '$timeStr | ${bill.merchantName ?? bill.note ?? ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceQuaternary(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '${isExpense ? "-" : "+"}¥${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface(isDark),
            ),
          ),
        ],
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
