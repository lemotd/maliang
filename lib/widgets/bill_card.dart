import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/memory_item.dart';
import '../utils/smooth_radius.dart';

class BillCard extends StatefulWidget {
  final List<MemoryItem> bills;

  const BillCard({super.key, required this.bills});

  @override
  State<BillCard> createState() => _BillCardState();
}

class _BillCardState extends State<BillCard> {
  bool _isHidden = false;

  double get _monthTotal {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    double total = 0;
    for (final bill in widget.bills) {
      if (bill.category == MemoryCategory.bill &&
          bill.createdAt.isAfter(monthStart)) {
        final amount = bill.amount ?? '0';
        final value =
            double.tryParse(amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        if (bill.isExpense ?? true) {
          total += value;
        }
      }
    }
    return total;
  }

  List<double> get _weeklyData {
    final now = DateTime.now();
    // 计算本周一的日期（00:00:00）
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day - (now.weekday - 1),
    );
    final data = List<double>.filled(7, 0);

    for (final bill in widget.bills) {
      if (bill.category == MemoryCategory.bill) {
        final billDate = bill.billTime ?? bill.createdAt;
        // 归一化到当天 00:00:00，避免时间差导致 inDays 计算偏移
        final billDay = DateTime(billDate.year, billDate.month, billDate.day);
        final daysDiff = billDay.difference(weekStart).inDays;
        if (daysDiff >= 0 && daysDiff < 7) {
          final amount = bill.amount ?? '0';
          final value =
              double.tryParse(amount.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
          if (bill.isExpense ?? true) {
            data[daysDiff] += value;
          }
        }
      }
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weeklyData = _weeklyData;
    final maxValue = weeklyData.isEmpty
        ? 1.0
        : weeklyData.reduce((a, b) => a > b ? a : b);

    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(isDark),
        borderRadius: smoothRadius(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _isHidden ? '****' : '¥${_monthTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: 'DINPro',
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurface(isDark),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isHidden = !_isHidden;
                    });
                  },
                  child: Icon(
                    _isHidden ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                    color: AppColors.onSurfaceQuaternary(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              '本月总支出',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceQuaternary(isDark),
              ),
            ),
            const Spacer(),
            _buildBarChart(weeklyData, maxValue, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<double> data, double maxValue, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final value = data[index];
              final height = maxValue > 0 ? (value / maxValue) * 40 : 0.0;
              final displayHeight = value > 0 ? height.clamp(4.0, 40.0) : 0.0;

              return Container(
                width: 12,
                height: 40,
                margin: EdgeInsets.only(right: index < 6 ? 1 : 0),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      width: 12,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer(isDark),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    if (displayHeight > 0)
                      Container(
                        width: 12,
                        height: displayHeight,
                        decoration: BoxDecoration(
                          color: AppColors.primary(isDark),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 24,
          height: 40,
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Text(
                  '0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    color: AppColors.onSurfaceQuaternary(isDark),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Text(
                  maxValue.toStringAsFixed(1),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    color: AppColors.onSurfaceQuaternary(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
