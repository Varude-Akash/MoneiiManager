import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/goals/domain/entities/savings_goal.dart';

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    this.onTap,
  });

  final SavingsGoal goal;
  final VoidCallback? onTap;

  Color get _goalColor {
    try {
      final hex = goal.color.replaceAll('#', '');
      final fullHex = hex.length == 6 ? 'FF$hex' : hex;
      return Color(int.parse(fullHex, radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _goalColor;
    final fmt = NumberFormat.currency(symbol: '', decimalDigits: 0);
    final currentStr = fmt.format(goal.currentAmount).trim();
    final targetStr = fmt.format(goal.targetAmount).trim();
    final pct = (goal.progress * 100).round();

    String deadlineText = 'No deadline';
    if (goal.deadline != null) {
      final daysLeft = goal.deadline!.difference(DateTime.now()).inDays;
      if (daysLeft < 0) {
        deadlineText = 'Overdue by ${daysLeft.abs()} days';
      } else if (daysLeft == 0) {
        deadlineText = 'Due today!';
      } else {
        deadlineText = '$daysLeft days left';
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Circular progress + emoji
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: goal.progress,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      goal.isCompleted ? AppColors.accentGreen : color,
                    ),
                    strokeWidth: 4,
                  ),
                  Text(
                    goal.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          goal.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (goal.isCompleted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '✓ Completed',
                            style: TextStyle(
                              color: AppColors.accentGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${goal.currency} $currentStr / $targetStr',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        deadlineText,
                        style: TextStyle(
                          color: goal.deadline != null &&
                                  goal.deadline!.isBefore(DateTime.now())
                              ? AppColors.error
                              : AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          color: goal.isCompleted
                              ? AppColors.accentGreen
                              : color,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
