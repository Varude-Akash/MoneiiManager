import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/utils/currency_utils.dart';
import 'package:moneii_manager/core/utils/date_utils.dart';
import 'package:moneii_manager/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/category_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/expense_provider.dart';
import 'package:moneii_manager/shared/widgets/glass_card.dart';
import 'package:moneii_manager/shared/widgets/shimmer_skeleton.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    final summary = ref.watch(analyticsSummaryProvider);

    if (expensesAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: const ExpenseListShimmer(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          _MonthSelector(
            selectedMonth: summary.selectedMonth,
            onMonthSelected: (month) {
              ref.read(selectedAnalyticsMonthProvider.notifier).state = month;
            },
          ),
          const SizedBox(height: 16),
          _SummaryCards(summary: summary),
          const SizedBox(height: 14),
          if (summary.categoryBreakdown.isEmpty)
            const _AnalyticsEmptyState()
          else ...[
            _PieCard(summary: summary),
            const SizedBox(height: 14),
            _DailyBarCard(summary: summary),
            const SizedBox(height: 14),
            _TrendCard(summary: summary),
            const SizedBox(height: 14),
            _BreakdownList(summary: summary),
          ],
        ],
      ).animate().fadeIn(duration: 260.ms),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.onMonthSelected,
  });

  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(
      12,
      (index) => DateTime(now.year, now.month - index),
    );

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final month = months[index];
          final selected =
              month.year == selectedMonth.year &&
              month.month == selectedMonth.month;
          return ChoiceChip(
            label: Text(AppDateUtils.formatMonth(month)),
            selected: selected,
            onSelected: (_) =>
                onMonthSelected(DateTime(month.year, month.month)),
          );
        },
      ),
    );
  }
}

class _SummaryCards extends ConsumerWidget {
  const _SummaryCards({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryByIdProvider);
    final biggestExpense = summary.biggestExpense;
    final biggestExpenseLabel = biggestExpense == null
        ? '-'
        : '${categories[biggestExpense.categoryId]?.name ?? 'Other'} ${CurrencyUtils.format(biggestExpense.amount)}';

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _MetricCard(
          title: 'Total Spent',
          value: CurrencyUtils.format(summary.totalSpent),
        ),
        _MetricCard(
          title: 'Daily Average',
          value: CurrencyUtils.format(summary.dailyAverage),
        ),
        _MetricCard(title: 'Biggest Expense', value: biggestExpenseLabel),
        _MetricCard(
          title: 'Most Frequent',
          value: summary.mostFrequentCategory,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PieCard extends ConsumerWidget {
  const _PieCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryByIdProvider);
    final total = summary.categoryBreakdown.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Breakdown',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 56,
                sections: summary.categoryBreakdown.map((item) {
                  final value = total == 0 ? 0.0 : item.total / total * 100;
                  final category = categories[item.categoryId];
                  return PieChartSectionData(
                    value: max(value, 0.5),
                    title: '${value.toStringAsFixed(0)}%',
                    radius: 56,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    color: category?.displayColor ?? AppColors.categoryOther,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyBarCard extends StatelessWidget {
  const _DailyBarCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final days = summary.dailySpending.entries.toList();
    final maxY = days.fold<double>(
      0,
      (max, day) => day.value > max ? day.value : max,
    );

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Spending',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY == 0 ? 100 : maxY * 1.2,
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() % 5 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: days.map((day) {
                  return BarChartGroupData(
                    x: day.key,
                    barRods: [
                      BarChartRodData(
                        toY: day.value,
                        width: 6,
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final points = summary.monthlyTrend
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
    final maxY = summary.monthlyTrend.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '6-Month Trend',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 5,
                minY: 0,
                maxY: maxY == 0 ? 100 : maxY * 1.2,
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: points,
                    color: AppColors.accentGreen,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
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

class _BreakdownList extends ConsumerWidget {
  const _BreakdownList({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryByIdProvider);

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category List',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...summary.categoryBreakdown.map((item) {
            final category = categories[item.categoryId];
            final percentage = summary.totalSpent == 0
                ? 0.0
                : item.total / summary.totalSpent;

            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        category?.iconData ?? Icons.category_rounded,
                        size: 18,
                        color:
                            category?.displayColor ?? AppColors.categoryOther,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.categoryName,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                      Text(
                        CurrencyUtils.format(item.total),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: percentage,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(100),
                    backgroundColor: AppColors.surfaceLight,
                    color: category?.displayColor ?? AppColors.categoryOther,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(24),
      child: const Column(
        children: [
          Icon(Icons.insights_rounded, color: AppColors.textMuted, size: 52),
          SizedBox(height: 12),
          Text(
            'No analytics yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Add expenses to unlock charts and trends.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
