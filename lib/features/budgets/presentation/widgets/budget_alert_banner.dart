import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/budgets/presentation/providers/budget_provider.dart';

class BudgetAlertBanner extends ConsumerStatefulWidget {
  const BudgetAlertBanner({super.key});

  @override
  ConsumerState<BudgetAlertBanner> createState() => _BudgetAlertBannerState();
}

class _BudgetAlertBannerState extends ConsumerState<BudgetAlertBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final alerts = ref.watch(overBudgetAlertsProvider);
    if (alerts.isEmpty) return const SizedBox.shrink();

    // Find the worst offender (highest percentage)
    final worst = alerts.reduce(
      (a, b) => a.percentage >= b.percentage ? a : b,
    );

    final budget = worst.budget;
    final remaining = budget.amount - worst.spentAmount;
    final pct = (worst.percentage * 100).round();
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 0);
    final remainingStr = fmt.format(remaining.abs()).trim();

    String message;
    if (worst.isOver) {
      message =
          '${budget.categoryName} budget is over by ${budget.currency} $remainingStr';
    } else {
      message =
          '${budget.categoryName} budget is $pct% used — ${budget.currency} $remainingStr left';
    }

    final bannerColor = worst.isOver
        ? AppColors.error.withValues(alpha: 0.15)
        : AppColors.accentOrange.withValues(alpha: 0.15);
    final borderColor =
        worst.isOver ? AppColors.error : AppColors.accentOrange;
    final iconColor = worst.isOver ? AppColors.error : AppColors.accentOrange;

    return GestureDetector(
      onTap: () => context.push('/analytics'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bannerColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              worst.isOver ? Iconsax.warning_2 : Iconsax.warning_2,
              color: iconColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _dismissed = true),
              child: Icon(
                Iconsax.close_circle,
                color: iconColor.withValues(alpha: 0.7),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
