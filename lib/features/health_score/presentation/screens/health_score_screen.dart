import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/health_score/presentation/providers/health_score_provider.dart';
import 'package:moneii_manager/features/subscriptions/presentation/providers/revenuecat_provider.dart';

class HealthScoreScreen extends ConsumerWidget {
  const HealthScoreScreen({super.key});

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
    // Save snapshot on init (best-effort)
    ref.read(saveHealthScoreProvider);

    final scoreAsync = ref.watch(healthScoreProvider);
    final historyAsync = ref.watch(healthScoreHistoryProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final purchases = ref.watch(revenueCatProvider);
    final isPremium = profile?.planTier == 'premium' ||
        profile?.planTier == 'premium_plus' ||
        purchases.hasMoneiiPro ||
        purchases.hasMoneiiProPlus;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Financial Health'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: scoreAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Text(
            'Could not load health score',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        data: (score) {
          final tier = _tierLabel(score.totalScore);
          final color = _tierColor(score.totalScore);
          final history = historyAsync.valueOrNull ?? [];

          final components = [
            _ScoreComponent(
              label: 'Savings Rate',
              icon: Iconsax.wallet,
              score: score.savingsScore,
              max: 30,
              color: AppColors.accentGreen,
              tip: score.savingsScore < 20
                  ? 'Aim to save 10%+ of your monthly income'
                  : null,
            ),
            _ScoreComponent(
              label: 'Budget Adherence',
              icon: Iconsax.chart_2,
              score: score.budgetScore,
              max: 25,
              color: AppColors.primary,
              tip: score.budgetScore < 15
                  ? 'Set budgets for more categories to track spending'
                  : null,
            ),
            _ScoreComponent(
              label: 'Credit Usage',
              icon: Iconsax.card,
              score: score.creditScore,
              max: 20,
              color: AppColors.accent,
              tip: score.creditScore < 15
                  ? 'Try to keep credit card usage below 30% of limit'
                  : null,
            ),
            _ScoreComponent(
              label: 'Logging Consistency',
              icon: Iconsax.calendar,
              score: score.consistencyScore,
              max: 15,
              color: AppColors.accentOrange,
              tip: score.consistencyScore < 10
                  ? 'Log transactions daily for a better score'
                  : null,
            ),
            _ScoreComponent(
              label: 'Income Coverage',
              icon: Iconsax.money,
              score: score.coverageScore,
              max: 10,
              color: const Color(0xFF34D399),
              tip: score.coverageScore < 10
                  ? 'Your expenses exceeded income this month'
                  : null,
            ),
          ];

          final tips =
              components.where((c) => c.tip != null).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Large score ring
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: score.totalScore / 100,
                            backgroundColor:
                                color.withValues(alpha: 0.15),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                            strokeWidth: 8,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${score.totalScore}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '/100',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tier,
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Components
              const Text(
                'Score Breakdown',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...components.map((c) => _ComponentRow(component: c)),
              const SizedBox(height: 20),

              // Tips
              if (tips.isNotEmpty) ...[
                const Text(
                  'What to Improve',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ...tips.map((c) => _TipRow(tip: c.tip!, icon: c.icon)),
                const SizedBox(height: 20),
              ],

              // History chart (premium)
              if (history.length >= 2) ...[
                const Divider(color: AppColors.surfaceLight),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Score History',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Pro',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isPremium)
                  _HistoryChart(history: history)
                else
                  _LockedChart(history: history),
                const SizedBox(height: 20),
              ],

              // Last updated footer
              Center(
                child: Text(
                  'Last updated: ${DateFormat('MMM d, yyyy').format(score.weekStart)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

// ─── Supporting classes and widgets ──────────────────────────────────────────

class _ScoreComponent {
  const _ScoreComponent({
    required this.label,
    required this.icon,
    required this.score,
    required this.max,
    required this.color,
    this.tip,
  });

  final String label;
  final IconData icon;
  final int score;
  final int max;
  final Color color;
  final String? tip;
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});
  final _ScoreComponent component;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: component.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(component.icon, color: component.color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      component.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${component.score} / ${component.max} pts',
                      style: TextStyle(
                        color: component.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: component.max > 0
                        ? component.score / component.max
                        : 0,
                    backgroundColor:
                        component.color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        component.color),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip, required this.icon});
  final String tip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.accentOrange.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentOrange, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                color: AppColors.accentOrange,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.history});
  final List<HealthScoreSnapshot> history;

  @override
  Widget build(BuildContext context) {
    final reversed = history.reversed.toList();
    final spots = reversed.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.totalScore.toDouble());
    }).toList();

    return SizedBox(
      height: 140,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.surfaceLight,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= reversed.length) {
                    return const SizedBox.shrink();
                  }
                  final date = reversed[idx].weekStart;
                  return Text(
                    '${date.month}/${date.day}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 9,
                    ),
                  );
                },
                reservedSize: 20,
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.accent.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedChart extends StatelessWidget {
  const _LockedChart({required this.history});
  final List<HealthScoreSnapshot> history;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Stack(
        children: [
          // Blurred chart preview
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: _HistoryChart(history: history),
          ),
          // Lock overlay
          Container(
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.lock, color: AppColors.textSecondary, size: 28),
                  SizedBox(height: 6),
                  Text(
                    'Upgrade to Pro to see your score history',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
