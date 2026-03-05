import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/health_score/presentation/providers/health_score_provider.dart';

class HealthScoreCard extends ConsumerWidget {
  const HealthScoreCard({super.key});

  static String _tierLabel(int score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Fair';
    if (score >= 30) return 'Needs Work';
    return 'Critical';
  }

  static Color _tierColor(int score) {
    if (score >= 85) return AppColors.accentGreen;
    if (score >= 70) return const Color(0xFF34D399);
    if (score >= 50) return AppColors.accentOrange;
    if (score >= 30) return const Color(0xFFF97316);
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(healthScoreProvider);
    final historyAsync = ref.watch(healthScoreHistoryProvider);

    return scoreAsync.when(
      loading: () => _LoadingCard(),
      error: (_, __) => const SizedBox.shrink(),
      data: (score) {
        final tier = _tierLabel(score.totalScore);
        final color = _tierColor(score.totalScore);

        // Delta from last week
        int? delta;
        final history = historyAsync.valueOrNull ?? [];
        if (history.length >= 2) {
          delta = history[0].totalScore - history[1].totalScore;
        }

        return GestureDetector(
          onTap: () => context.push('/health-score'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Score ring
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: score.totalScore / 100,
                        backgroundColor:
                            color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        strokeWidth: 5,
                      ),
                      Text(
                        '${score.totalScore}',
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Label + delta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Financial Health',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tier,
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (delta != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              delta! >= 0
                                  ? Iconsax.arrow_up_3
                                  : Iconsax.arrow_down_2,
                              color: delta! >= 0
                                  ? AppColors.accentGreen
                                  : AppColors.error,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${delta! >= 0 ? '+' : ''}$delta from last week',
                              style: TextStyle(
                                color: delta! >= 0
                                    ? AppColors.accentGreen
                                    : AppColors.error,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const Icon(
                  Iconsax.arrow_right_3,
                  color: AppColors.textMuted,
                  size: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceLight,
      highlightColor: AppColors.card,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
