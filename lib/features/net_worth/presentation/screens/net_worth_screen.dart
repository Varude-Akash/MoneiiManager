import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/net_worth/presentation/providers/net_worth_provider.dart';
import 'package:moneii_manager/features/profile/presentation/providers/financial_account_provider.dart';

class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(netWorthProvider);
    final accountsAsync = ref.watch(financialAccountsProvider);
    final historyAsync = ref.watch(netWorthHistoryProvider);

    // Save snapshot on first build (best-effort, fire and forget)
    ref.listen(saveNetWorthSnapshotProvider, (_, __) {});
    // Trigger the provider
    ref.read(saveNetWorthSnapshotProvider);

    final profile = ref.watch(profileProvider).valueOrNull;
    final currency = profile?.currencyPreference ?? 'USD';
    final fmt = NumberFormat.currency(
      symbol: NumberFormat.currency(name: currency).currencySymbol,
      decimalDigits: 0,
    );

    final accounts = accountsAsync.valueOrNull ?? [];
    final assetAccounts = accounts
        .where((a) =>
            a.accountType == 'bank_account' || a.accountType == 'wallet')
        .toList();
    final liabilityAccounts =
        accounts.where((a) => a.accountType == 'credit_card').toList();

    final history = historyAsync.valueOrNull ?? [];
    double? delta;
    if (history.length >= 2) {
      delta = history[0].netWorth - history[1].netWorth;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Net Worth'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: accounts.isEmpty && accountsAsync.hasValue
          ? _EmptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Large net worth number
                _NetWorthHeader(
                  summary: summary,
                  delta: delta,
                  fmt: fmt,
                ),
                const SizedBox(height: 20),

                // Assets section
                if (assetAccounts.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Assets',
                    amount: fmt.format(summary.assets),
                    color: AppColors.accentGreen,
                  ),
                  const SizedBox(height: 8),
                  ...assetAccounts.map((a) => _AccountRow(
                        name: a.name,
                        amount: fmt.format(a.currentBalance),
                        icon: a.accountType == 'wallet'
                            ? Iconsax.wallet
                            : Iconsax.bank,
                        color: AppColors.accentGreen,
                      )),
                  const SizedBox(height: 16),
                ],

                // Liabilities section
                if (liabilityAccounts.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Liabilities',
                    amount: fmt.format(summary.liabilities),
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 8),
                  ...liabilityAccounts.map((a) => _AccountRow(
                        name: a.name,
                        amount: fmt.format(a.utilizedAmount),
                        subtitle:
                            'Limit: ${fmt.format(a.creditLimit)}  •  '
                            '${a.creditLimit > 0 ? ((a.utilizedAmount / a.creditLimit) * 100).round() : 0}% used',
                        icon: Iconsax.card,
                        color: AppColors.error,
                      )),
                  const SizedBox(height: 16),
                ],

                // Chart
                if (history.length >= 2) ...[
                  const Divider(color: AppColors.surfaceLight),
                  const SizedBox(height: 16),
                  const Text(
                    'Net Worth Over Time',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _NetWorthChart(
                    history: history.reversed
                        .take(6)
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _NetWorthHeader extends StatelessWidget {
  const _NetWorthHeader({
    required this.summary,
    required this.delta,
    required this.fmt,
  });

  final NetWorthSummary summary;
  final double? delta;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final isPositive = summary.netWorth >= 0;
    final isDeltaPositive = (delta ?? 0) >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Net Worth',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fmt.format(summary.netWorth),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  isDeltaPositive ? Iconsax.arrow_up_3 : Iconsax.arrow_down_2,
                  color: isDeltaPositive
                      ? AppColors.accentGreen
                      : AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isDeltaPositive ? '+' : ''}${fmt.format(delta!)} vs last snapshot',
                  style: TextStyle(
                    color: isDeltaPositive
                        ? AppColors.accentGreen
                        : AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _StatPill(
                label: 'Assets',
                value: fmt.format(summary.assets),
                color: AppColors.accentGreen,
              ),
              const SizedBox(width: 12),
              _StatPill(
                label: 'Liabilities',
                value: fmt.format(summary.liabilities),
                color: AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.amount,
    required this.color,
  });

  final String title;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.name,
    required this.amount,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  final String name;
  final String amount;
  final String? subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetWorthChart extends StatelessWidget {
  const _NetWorthChart({required this.history});

  final List<NetWorthSnapshot> history;

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) return const SizedBox.shrink();

    final spots = history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.netWorth);
    }).toList();

    final minY = history.map((e) => e.netWorth).reduce((a, b) => a < b ? a : b);
    final maxY = history.map((e) => e.netWorth).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY).abs() * 0.1 + 1;

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: minY - padding,
          maxY: maxY + padding,
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
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= history.length) {
                    return const SizedBox.shrink();
                  }
                  final date = history[idx].snapshotDate;
                  return Text(
                    '${date.month}/${date.day}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                    ),
                  );
                },
                reservedSize: 22,
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.chart_2, color: AppColors.textMuted, size: 64),
            const SizedBox(height: 16),
            const Text(
              'No accounts yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add bank accounts and credit cards to track your net worth.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
