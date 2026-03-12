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

    return Scaffold(
      backgroundColor: AppColors.surfaceLow(isDark),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  _buildMonthCard(isDark),
                  const SizedBox(height: 16),
                  ..._billsByDate.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildDayCard(entry.key, entry.value, isDark),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          Positioned(
            left: 8,
            top: 0,
            child: GlassButton(
              icon: CupertinoIcons.back,
              onTap: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            left: 60,
            right: 60,
            top: 0,
            child: SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  '总账单',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface(isDark),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCard(bool isDark) {
    final now = DateTime.now();
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];

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
