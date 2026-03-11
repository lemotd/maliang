import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AddCollectionCard extends StatelessWidget {
  final VoidCallback? onTap;

  const AddCollectionCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh(isDark),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer(isDark),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 24,
                color: AppColors.onSurfaceQuaternary(isDark),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '新建合集',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.onSurfaceQuaternary(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
