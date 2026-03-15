import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/net_worth/presentation/providers/net_worth_provider.dart';
import 'package:moneii_manager/features/subscriptions/presentation/providers/revenuecat_provider.dart';

class NetWorthSummaryCard extends ConsumerWidget {
  const NetWorthSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(netWorthProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final purchases = ref.watch(revenueCatProvider);
    final milestone = ref.watch(netWorthMilestoneProvider);

    final currency = profile?.currencyPreference ?? 'USD';
    final currencySymbol = NumberFormat.currency(name: currency).currencySymbol;
    final fmt = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);

    final isPositive = summary.netWorth >= 0;
    final isPro = profile?.planTier == 'premium' ||
        profile?.planTier == 'premium_plus' ||
        purchases.hasMoneiiPro ||
        purchases.hasMoneiiProPlus;

    return GestureDetector(
      onTap: () => context.push('/net-worth'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Net Worth',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Icon(
                  Iconsax.arrow_right_3,
                  color: AppColors.textMuted,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Large net worth number
            Text(
              fmt.format(summary.netWorth),
              style: TextStyle(
                color: isPositive ? AppColors.textPrimary : AppColors.error,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Assets / Liabilities row
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Assets',
                    value: fmt.format(summary.assets),
                    color: AppColors.accentGreen,
                    icon: Iconsax.bank,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'Liabilities',
                    value: fmt.format(summary.liabilities),
                    color: AppColors.error,
                    icon: Iconsax.card,
                  ),
                ),
              ],
            ),

            // Milestone progress bar (Pro only)
            if (isPro && milestone != null) ...[
              const SizedBox(height: 14),
              _MilestoneProgressBar(
                milestone: milestone,
                currencySymbol: currencySymbol,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MilestoneProgressBar extends StatelessWidget {
  const _MilestoneProgressBar({
    required this.milestone,
    required this.currencySymbol,
  });

  final NetWorthMilestoneData milestone;
  final String currencySymbol;

  String _format(double value) {
    if (value >= 1000000) {
      return '$currencySymbol${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '$currencySymbol${(value / 1000).toStringAsFixed(0)}K';
    }
    return '$currencySymbol${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('🎯 ', style: TextStyle(fontSize: 12)),
                Text(
                  'Next milestone: ${_format(milestone.nextMilestone)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              '${(milestone.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: milestone.progress,
            minHeight: 6,
            backgroundColor: AppColors.glassBorder,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        if (milestone.monthsToNext != null) ...[
          const SizedBox(height: 4),
          Text(
            'At your pace, ~${milestone.monthsToNext!.toStringAsFixed(0)} months away',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
