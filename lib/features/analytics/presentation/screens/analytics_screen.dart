import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/utils/currency_utils.dart';
import 'package:moneii_manager/core/utils/date_utils.dart';
import 'package:moneii_manager/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:moneii_manager/features/expenses/domain/entities/expense.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/category_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/expense_provider.dart';
import 'package:moneii_manager/shared/widgets/glass_card.dart';
import 'package:moneii_manager/shared/widgets/shimmer_skeleton.dart';

enum AnalyticsViewMode { combined, expense, income }

final analyticsViewModeProvider = StateProvider<AnalyticsViewMode>(
  (ref) => AnalyticsViewMode.combined,
);

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    final summary = ref.watch(analyticsSummaryProvider);
    final viewMode = ref.watch(analyticsViewModeProvider);
    final expenses = expensesAsync.valueOrNull ?? <Expense>[];
    final earliestMonth = _earliestMonth(expenses);

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
            earliestMonth: earliestMonth,
            onMonthSelected: (month) {
              ref.read(selectedAnalyticsMonthProvider.notifier).state = month;
            },
          ),
          const SizedBox(height: 10),
          _ModeToggle(
            selected: viewMode,
            onChanged: (mode) {
              ref.read(analyticsViewModeProvider.notifier).state = mode;
            },
          ),
          const SizedBox(height: 10),
          _SelectedMonthSpendCard(summary: summary),
          const SizedBox(height: 12),
          if (viewMode == AnalyticsViewMode.combined) ...[
            _NetFlowStrip(summary: summary),
            const SizedBox(height: 12),
            _ExpenseSection(summary: summary),
            const SizedBox(height: 12),
            _IncomeSection(summary: summary),
          ] else if (viewMode == AnalyticsViewMode.expense) ...[
            _ExpenseSection(summary: summary),
          ] else ...[
            _IncomeSection(summary: summary),
          ],
        ],
      ).animate().fadeIn(duration: 220.ms),
    );
  }

  DateTime _earliestMonth(List<Expense> expenses) {
    if (expenses.isEmpty) {
      final now = DateTime.now();
      return DateTime(now.year, now.month);
    }

    var earliest = expenses.first.expenseDate;
    for (final expense in expenses) {
      final date = expense.expenseDate;
      if (date.isBefore(earliest)) earliest = date;
    }
    return DateTime(earliest.year, earliest.month);
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.selected, required this.onChanged});

  final AnalyticsViewMode selected;
  final ValueChanged<AnalyticsViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(AnalyticsViewMode mode, String label) {
      return ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11.5)),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selected: selected == mode,
        onSelected: (_) => onChanged(mode),
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        chip(AnalyticsViewMode.combined, 'Combined'),
        chip(AnalyticsViewMode.expense, 'Expense'),
        chip(AnalyticsViewMode.income, 'Income'),
      ],
    );
  }
}

class _MonthSelector extends StatefulWidget {
  const _MonthSelector({
    required this.selectedMonth,
    required this.earliestMonth,
    required this.onMonthSelected,
  });

  final DateTime selectedMonth;
  final DateTime earliestMonth;
  final ValueChanged<DateTime> onMonthSelected;

  @override
  State<_MonthSelector> createState() => _MonthSelectorState();
}

class _MonthSelectorState extends State<_MonthSelector> {
  late final ScrollController _controller;
  var _canScrollLeft = false;
  var _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_syncIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndicators());
  }

  @override
  void dispose() {
    _controller.removeListener(_syncIndicators);
    _controller.dispose();
    super.dispose();
  }

  void _syncIndicators() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final offset = _controller.offset;
    final nextLeft = offset > 4;
    final nextRight = offset < max - 4;
    if (nextLeft != _canScrollLeft || nextRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = nextLeft;
        _canScrollRight = nextRight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthCount =
        ((now.year - widget.earliestMonth.year) * 12) +
        (now.month - widget.earliestMonth.month) +
        1;
    final safeCount = monthCount.clamp(1, 600);
    final months = List.generate(
      safeCount,
      (index) => DateTime(now.year, now.month - index),
    );

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  itemCount: months.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final month = months[index];
                    final selected =
                        month.year == widget.selectedMonth.year &&
                        month.month == widget.selectedMonth.month;
                    return ChoiceChip(
                      label: Text(
                        AppDateUtils.formatMonth(month),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selected: selected,
                      onSelected: (_) => widget.onMonthSelected(
                        DateTime(month.year, month.month),
                      ),
                    );
                  },
                ),
                if (_canScrollLeft)
                  const Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: _ScrollEdgeIndicator(
                      alignment: Alignment.centerLeft,
                      icon: Icons.chevron_left_rounded,
                    ),
                  ),
                if (_canScrollRight)
                  const Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: _ScrollEdgeIndicator(
                      alignment: Alignment.centerRight,
                      icon: Icons.chevron_right_rounded,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Jump to month',
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.selectedMonth,
                firstDate: widget.earliestMonth,
                lastDate: DateTime(now.year, now.month, now.day),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.primary,
                        surface: AppColors.surface,
                      ),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
              if (picked != null) {
                widget.onMonthSelected(DateTime(picked.year, picked.month));
              }
            },
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
    );
  }
}

class _ScrollEdgeIndicator extends StatelessWidget {
  const _ScrollEdgeIndicator({required this.alignment, required this.icon});

  final Alignment alignment;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 26,
        alignment: alignment,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: alignment == Alignment.centerLeft
                ? Alignment.centerLeft
                : Alignment.centerRight,
            end: alignment == Alignment.centerLeft
                ? Alignment.centerRight
                : Alignment.centerLeft,
            colors: [
              AppColors.background.withValues(alpha: 0.95),
              AppColors.background.withValues(alpha: 0),
            ],
          ),
        ),
        child: Icon(icon, size: 18, color: AppColors.textMuted),
      ),
    );
  }
}

class _NetFlowStrip extends StatelessWidget {
  const _NetFlowStrip({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final netColor = summary.netFlow >= 0 ? AppColors.accentGreen : AppColors.error;
    return GlassCard(
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: _TinyMetric(
              label: 'Expense',
              value: CurrencyUtils.format(
                summary.totalSpent,
                currency: summary.preferredCurrency,
              ),
            ),
          ),
          Expanded(
            child: _TinyMetric(
              label: 'Income',
              value: CurrencyUtils.format(
                summary.totalIncome,
                currency: summary.preferredCurrency,
              ),
            ),
          ),
          Expanded(
            child: _TinyMetric(
              label: 'Net',
              value:
                  '${summary.netFlow >= 0 ? '+' : '-'}${CurrencyUtils.format(summary.netFlow.abs(), currency: summary.preferredCurrency)}',
              valueColor: netColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedMonthSpendCard extends StatelessWidget {
  const _SelectedMonthSpendCard({required this.summary});

  final AnalyticsSummary summary;

  String _compactNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final entries = summary.dailySpending.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final hasData = entries.isNotEmpty;
    final spots = hasData
        ? entries
              .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
              .toList()
        : <FlSpot>[const FlSpot(1, 0)];
    final double maxX = hasData ? entries.last.key.toDouble() : 31.0;
    final maxY = entries.fold<double>(
      0,
      (max, entry) => entry.value > max ? entry.value : max,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        return GlassCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Spent in ${AppDateUtils.formatMonth(summary.selectedMonth).toLowerCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: compact ? 12 : 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    CurrencyUtils.format(
                      summary.totalSpent,
                      currency: summary.preferredCurrency,
                    ),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: compact ? 20 : 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: compact ? 88 : 96,
                child: LineChart(
              LineChartData(
                minX: 1.0,
                maxX: maxX <= 1.0 ? 31.0 : maxX,
                minY: 0,
                maxY: maxY == 0 ? 100 : maxY * 1.2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY == 0 ? 50 : (maxY / 2),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.glassBorder.withValues(alpha: 0.22),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: maxY == 0 ? 50 : (maxY / 2),
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text(
                          _compactNumber(value),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 16,
                      interval: 7,
                      getTitlesWidget: (value, meta) {
                        final day = value.toInt();
                        if (day < 1 || day > 31) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          day.toString(),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  enabled: hasData,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceLight,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          'Day ${spot.x.toInt()} ${CurrencyUtils.format(spot.y, currency: summary.preferredCurrency)}',
                          const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.accent,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withValues(alpha: 0.28),
                          AppColors.accent.withValues(alpha: 0.01),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TinyMetric extends StatelessWidget {
  const _TinyMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseSection extends ConsumerWidget {
  const _ExpenseSection({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryByIdProvider);
    final hasExpenseData = summary.totalSpent > 0;
    final biggestExpenseLabel = summary.biggestExpense == null
        ? '-'
        : '${categories[summary.biggestExpense!.categoryId]?.name ?? 'Other'} • ${CurrencyUtils.format(summary.biggestExpenseAmount, currency: summary.preferredCurrency)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return GlassCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                title: 'Expense Analytics',
                subtitle: 'Spending patterns, categories, and trends',
                compact: compact,
              ),
              SizedBox(height: compact ? 8 : 12),
              Wrap(
                spacing: compact ? 6 : 8,
                runSpacing: compact ? 6 : 8,
                children: [
                  _MiniPill(
                    label: 'Total',
                    value: CurrencyUtils.format(
                      summary.totalSpent,
                      currency: summary.preferredCurrency,
                    ),
                    compact: compact,
                  ),
                  _MiniPill(
                    label: 'Daily Avg',
                    value: CurrencyUtils.format(
                      summary.dailyAverage,
                      currency: summary.preferredCurrency,
                    ),
                    compact: compact,
                  ),
                  _MiniPill(
                    label: 'Biggest',
                    value: biggestExpenseLabel,
                    compact: compact,
                  ),
                  _MiniPill(
                    label: 'Frequent',
                    value: summary.mostFrequentCategory,
                    compact: compact,
                  ),
                ],
              ),
          if (!hasExpenseData) ...[
            const SizedBox(height: 14),
            const Text(
              'No expense data for this month yet.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ] else ...[
            const SizedBox(height: 16),
            _ExpensePieWithLegend(summary: summary),
            const SizedBox(height: 16),
            _BarWithValues(
              title: 'Daily Spending',
              values: summary.dailySpending,
              preferredCurrency: summary.preferredCurrency,
              color: AppColors.accent,
            ),
            const SizedBox(height: 16),
            _TrendLine(
              title: '6-Month Expense Trend',
              values: summary.monthlyTrend,
              color: AppColors.accent,
              preferredCurrency: summary.preferredCurrency,
            ),
          ],
            ],
          ),
        );
      },
    );
  }
}

class _IncomeSection extends ConsumerWidget {
  const _IncomeSection({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryByIdProvider);
    final hasIncomeData = summary.totalIncome > 0;
    final biggestIncomeLabel = summary.biggestIncome == null
        ? '-'
        : '${categories[summary.biggestIncome!.categoryId]?.name ?? 'Income'} • ${CurrencyUtils.format(summary.biggestIncomeAmount, currency: summary.preferredCurrency)}';

    return GlassCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Income Analytics',
            subtitle: 'Cash-in visibility and income trends',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniPill(
                label: 'Total',
                value: CurrencyUtils.format(
                  summary.totalIncome,
                  currency: summary.preferredCurrency,
                ),
              ),
              _MiniPill(
                label: 'Daily Avg',
                value: CurrencyUtils.format(
                  summary.dailyIncomeAverage,
                  currency: summary.preferredCurrency,
                ),
              ),
              _MiniPill(label: 'Biggest', value: biggestIncomeLabel),
            ],
          ),
          if (!hasIncomeData) ...[
            const SizedBox(height: 14),
            const Text(
              'No income data for this month yet.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ] else ...[
            const SizedBox(height: 16),
            _BarWithValues(
              title: 'Daily Income',
              values: summary.dailyIncome,
              preferredCurrency: summary.preferredCurrency,
              color: AppColors.accentGreen,
            ),
            const SizedBox(height: 16),
            _TrendLine(
              title: '6-Month Income Trend',
              values: summary.monthlyIncomeTrend,
              color: AppColors.accentGreen,
              preferredCurrency: summary.preferredCurrency,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpensePieWithLegend extends ConsumerWidget {
  const _ExpensePieWithLegend({required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoryByIdProvider);
    final total = summary.categoryBreakdown.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final chartHeight = compact ? 170.0 : 200.0;
        final sectionRadius = compact ? 40.0 : 48.0;
        final centerRadius = compact ? 36.0 : 44.0;
        final legendWidth = compact ? 128.0 : 150.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Breakdown',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: chartHeight,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: centerRadius,
                        sections: summary.categoryBreakdown.map((item) {
                          final value = total == 0 ? 0.0 : item.total / total * 100;
                          final category = categories[item.categoryId];
                          return PieChartSectionData(
                            value: max(value, 0.5),
                            title: '${value.toStringAsFixed(0)}%',
                            radius: sectionRadius,
                            titleStyle: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: compact ? 9 : 10,
                            ),
                            color: category?.displayColor ?? AppColors.categoryOther,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: legendWidth,
                    child: ListView(
                      children: summary.categoryBreakdown.map((item) {
                        final category = categories[item.categoryId];
                        final percent = total == 0 ? 0 : (item.total / total * 100);
                        final color = category?.displayColor ?? AppColors.categoryOther;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.categoryName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: compact ? 10 : 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${percent.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: compact ? 10 : 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BarWithValues extends StatelessWidget {
  const _BarWithValues({
    required this.title,
    required this.values,
    required this.preferredCurrency,
    required this.color,
  });

  final String title;
  final Map<int, double> values;
  final String preferredCurrency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList();
    final maxY = entries.fold<double>(
      0,
      (max, day) => day.value > max ? day.value : max,
    );
    final nonZero = entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final latest = nonZero.take(7).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY == 0 ? 100 : maxY * 1.2,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                horizontalInterval: maxY == 0 ? 25 : maxY / 4,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: AppColors.glassBorder.withValues(alpha: 0.35),
                    strokeWidth: 1,
                  );
                },
                drawVerticalLine: false,
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      if (maxY == 0) return const SizedBox.shrink();
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                        ),
                      );
                    },
                  ),
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
                    reservedSize: 18,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() % 5 != 0) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: entries.map((day) {
                return BarChartGroupData(
                  x: day.key,
                  barRods: [
                    BarChartRodData(
                      toY: day.value,
                      width: 6,
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (latest.isEmpty)
          const Text(
            'No values yet',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: latest.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  'Day ${entry.key}: ${CurrencyUtils.format(entry.value, currency: preferredCurrency)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({
    required this.title,
    required this.values,
    required this.color,
    required this.preferredCurrency,
  });

  final String title;
  final List<double> values;
  final Color color;
  final String preferredCurrency;

  String _compactNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  String _monthLabel(int indexFromStart) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month - (5 - indexFromStart));
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final points = values
        .asMap()
        .entries
        .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
        .toList();
    final maxY = values.fold<double>(0, (max, value) => value > max ? value : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        SizedBox(
          height: 125,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 5,
              minY: 0,
              maxY: maxY == 0 ? 100 : maxY * 1.2,
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: maxY == 0 ? 50 : maxY / 2,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Text(
                        _compactNumber(value),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 16,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index > 5) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        _monthLabel(index),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.glassBorder.withValues(alpha: 0.35),
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => AppColors.surfaceLight,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      final month = _monthLabel(index);
                      return LineTooltipItem(
                        '$month ${CurrencyUtils.format(spot.y, currency: preferredCurrency)}',
                        const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: points,
                  color: color,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  barWidth: 3,
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.12),
                  ),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, xPercent, barData, index) => FlDotCirclePainter(
                      radius: 2.6,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: compact ? 98 : 110,
        maxWidth: compact ? 198 : 220,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: compact ? 9.5 : 10,
            ),
          ),
          SizedBox(height: compact ? 2 : 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: compact ? 1 : 2),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: compact ? 11 : 12,
          ),
        ),
      ],
    );
  }
}
