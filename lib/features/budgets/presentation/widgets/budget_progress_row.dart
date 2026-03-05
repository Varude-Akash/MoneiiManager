import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/budgets/presentation/providers/budget_provider.dart';
import 'package:moneii_manager/features/budgets/presentation/widgets/set_budget_sheet.dart';

class BudgetProgressRow extends StatelessWidget {
  const BudgetProgressRow({
    super.key,
    required this.progress,
    this.onTap,
  });

  final BudgetProgress progress;
  final VoidCallback? onTap;

  Color get _progressColor {
    final pct = progress.percentage;
    if (pct >= 1.0) return AppColors.error;
    if (pct >= 0.8) return AppColors.accentOrange;
    if (pct >= 0.6) return const Color(0xFFF59E0B); // amber
    return AppColors.accentGreen;
  }

  @override
  Widget build(BuildContext context) {
    final budget = progress.budget;
    final fmt = NumberFormat.currency(
      symbol: '',
      decimalDigits: 0,
    );
    final spentStr = fmt.format(progress.spentAmount).trim();
    final totalStr = fmt.format(budget.amount).trim();
    final pctStr = '${(progress.percentage * 100).round()}%';
    final remaining = budget.amount - progress.spentAmount;

    return InkWell(
      onTap: onTap ??
          () {
            SetBudgetSheet.show(
              context,
              categoryId: budget.categoryId,
              categoryName: budget.categoryName,
              existingBudget: budget,
            );
          },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: category name + percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    budget.categoryName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  pctStr,
                  style: TextStyle(
                    color: _progressColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.percentage.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceLight,
                valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),

            // Bottom row: spent / total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spent ${budget.currency} $spentStr of $totalStr',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (remaining >= 0)
                  Text(
                    '${budget.currency} ${fmt.format(remaining).trim()} left',
                    style: TextStyle(
                      color: progress.isOver
                          ? AppColors.error
                          : AppColors.textMuted,
                      fontSize: 12,
                    ),
                  )
                else
                  Text(
                    '${budget.currency} ${fmt.format(remaining.abs()).trim()} over',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
