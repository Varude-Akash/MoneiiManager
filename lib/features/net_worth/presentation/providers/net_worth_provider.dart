import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/expense_provider.dart';
import 'package:moneii_manager/features/profile/presentation/providers/financial_account_provider.dart';

// ─── NetWorthSummary ──────────────────────────────────────────────────────────

class NetWorthSummary {
  const NetWorthSummary({
    required this.assets,
    required this.liabilities,
  });

  final double assets;
  final double liabilities;
  double get netWorth => assets - liabilities;

  static const zero = NetWorthSummary(assets: 0, liabilities: 0);
}

// ─── netWorthProvider ─────────────────────────────────────────────────────────

final netWorthProvider = Provider<NetWorthSummary>((ref) {
  final accountsAsync = ref.watch(financialAccountsProvider);
  final accounts = accountsAsync.valueOrNull ?? [];

  if (accounts.isEmpty) return NetWorthSummary.zero;

  double assets = 0;
  double liabilities = 0;

  for (final account in accounts) {
    if (account.accountType == 'bank_account' ||
        account.accountType == 'wallet') {
      assets += account.currentBalance;
    } else if (account.accountType == 'credit_card') {
      liabilities += account.utilizedAmount;
    }
  }

  return NetWorthSummary(assets: assets, liabilities: liabilities);
});

// ─── NetWorthSnapshot ────────────────────────────────────────────────────────

class NetWorthSnapshot {
  const NetWorthSnapshot({
    required this.netWorth,
    required this.assets,
    required this.liabilities,
    required this.snapshotDate,
  });

  final double netWorth;
  final double assets;
  final double liabilities;
  final DateTime snapshotDate;

  factory NetWorthSnapshot.fromJson(Map<String, dynamic> json) {
    return NetWorthSnapshot(
      netWorth: (json['net_worth'] as num?)?.toDouble() ?? 0,
      assets: (json['assets'] as num?)?.toDouble() ?? 0,
      liabilities: (json['liabilities'] as num?)?.toDouble() ?? 0,
      snapshotDate: DateTime.parse(
        json['snapshot_date'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

// ─── netWorthHistoryProvider ─────────────────────────────────────────────────

final netWorthHistoryProvider =
    FutureProvider<List<NetWorthSnapshot>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('net_worth_snapshots')
      .select('*')
      .eq('user_id', user.id)
      .order('snapshot_date', ascending: false)
      .limit(12);

  return (data as List)
      .map((e) => NetWorthSnapshot.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─── saveNetWorthSnapshotProvider ────────────────────────────────────────────

final saveNetWorthSnapshotProvider = FutureProvider<void>((ref) async {
  try {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final client = ref.read(supabaseClientProvider);
    final summary = ref.read(netWorthProvider);
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    await client.from('net_worth_snapshots').upsert({
      'user_id': user.id,
      'snapshot_date': dateStr,
      'net_worth': summary.netWorth,
      'assets': summary.assets,
      'liabilities': summary.liabilities,
    }, onConflict: 'user_id,snapshot_date');
  } catch (_) {
    // Silently handle errors — snapshot saving is best-effort.
  }
});

// ─── Milestone thresholds ─────────────────────────────────────────────────────

const List<double> _milestoneThresholds = [
  1000, 5000, 10000, 25000, 50000, 100000,
  250000, 500000, 1000000, 2500000, 5000000, 10000000,
];

// ─── NetWorthMilestoneData ────────────────────────────────────────────────────

class NetWorthMilestoneData {
  const NetWorthMilestoneData({
    required this.currentNetWorth,
    required this.previousMilestone,
    required this.nextMilestone,
    required this.progress,
    this.monthsToNext,
  });

  final double currentNetWorth;
  final double previousMilestone;
  final double nextMilestone;
  final double progress; // 0.0 – 1.0
  final double? monthsToNext;
}

final netWorthMilestoneProvider = Provider<NetWorthMilestoneData?>((ref) {
  final summary = ref.watch(netWorthProvider);
  final netWorth = summary.netWorth;
  if (netWorth <= 0) return null;

  final nextMilestone = _milestoneThresholds.firstWhere(
    (t) => t > netWorth,
    orElse: () => _milestoneThresholds.last * 2,
  );
  final prevIdx = _milestoneThresholds.lastIndexWhere((t) => t <= netWorth);
  final previousMilestone = prevIdx >= 0 ? _milestoneThresholds[prevIdx] : 0.0;

  final range = nextMilestone - previousMilestone;
  final progress = range > 0 ? (netWorth - previousMilestone) / range : 1.0;

  final history = ref.watch(netWorthHistoryProvider).valueOrNull;
  double? monthsToNext;
  if (history != null && history.length >= 2) {
    final sorted = [...history]
      ..sort((a, b) => a.snapshotDate.compareTo(b.snapshotDate));
    final pts = sorted.length >= 4 ? sorted.sublist(sorted.length - 4) : sorted;
    double totalDelta = 0;
    int totalDays = 0;
    for (int i = 1; i < pts.length; i++) {
      final days = pts[i].snapshotDate.difference(pts[i - 1].snapshotDate).inDays;
      if (days > 0) {
        totalDelta += pts[i].netWorth - pts[i - 1].netWorth;
        totalDays += days;
      }
    }
    if (totalDays > 0 && totalDelta > 0) {
      final monthlyGrowth = (totalDelta / totalDays) * 30;
      monthsToNext = (nextMilestone - netWorth) / monthlyGrowth;
    }
  }

  return NetWorthMilestoneData(
    currentNetWorth: netWorth,
    previousMilestone: previousMilestone,
    nextMilestone: nextMilestone,
    progress: progress.clamp(0.0, 1.0),
    monthsToNext: monthsToNext,
  );
});

// ─── IdleCashAlertData ────────────────────────────────────────────────────────

class IdleCashAlertData {
  const IdleCashAlertData({
    required this.idleAmount,
    required this.monthlyErosion,
  });

  final double idleAmount;
  final double monthlyErosion;
}

final idleCashAlertProvider = Provider<IdleCashAlertData?>((ref) {
  final accounts = ref.watch(financialAccountsProvider).valueOrNull ?? [];
  final expenses = ref.watch(expensesProvider).valueOrNull ?? [];

  final liquidAssets = accounts
      .where((a) => a.accountType == 'bank_account' || a.accountType == 'wallet')
      .fold<double>(0, (sum, a) => sum + a.currentBalance);

  if (liquidAssets <= 0) return null;

  final now = DateTime.now();
  final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
  final recentTotal = expenses
      .where((e) =>
          e.transactionType == 'expense' &&
          e.expenseDate.isAfter(threeMonthsAgo))
      .fold<double>(0, (sum, e) => sum + e.amount);

  final avgMonthlyExpenses = recentTotal / 3;
  if (avgMonthlyExpenses <= 0) return null;

  final safetyBuffer = avgMonthlyExpenses * 3;
  final idleAmount = liquidAssets - safetyBuffer;

  // Only alert if idle amount is at least 50% of monthly expenses (avoid noise)
  if (idleAmount < avgMonthlyExpenses * 0.5) return null;

  const annualInflation = 0.035;
  final monthlyErosion = idleAmount * (annualInflation / 12);

  return IdleCashAlertData(
    idleAmount: idleAmount,
    monthlyErosion: monthlyErosion,
  );
});

// ─── NetWorthProjection ───────────────────────────────────────────────────────

class NetWorthProjection {
  const NetWorthProjection({required this.projectedPoints});
  final List<NetWorthSnapshot> projectedPoints;
}

final netWorthProjectionProvider = Provider<NetWorthProjection?>((ref) {
  final history = ref.watch(netWorthHistoryProvider).valueOrNull;
  if (history == null || history.length < 2) return null;

  final sorted = [...history]
    ..sort((a, b) => a.snapshotDate.compareTo(b.snapshotDate));
  final pts = sorted.length >= 4 ? sorted.sublist(sorted.length - 4) : sorted;

  double totalDelta = 0;
  int totalDays = 0;
  for (int i = 1; i < pts.length; i++) {
    final days = pts[i].snapshotDate.difference(pts[i - 1].snapshotDate).inDays;
    if (days > 0) {
      totalDelta += pts[i].netWorth - pts[i - 1].netWorth;
      totalDays += days;
    }
  }
  if (totalDays == 0) return null;

  final dailyGrowth = totalDelta / totalDays;
  final last = pts.last;

  final projected = List.generate(3, (i) {
    final daysAhead = (i + 1) * 30;
    return NetWorthSnapshot(
      netWorth: last.netWorth + dailyGrowth * daysAhead,
      assets: last.assets + dailyGrowth * daysAhead,
      liabilities: last.liabilities,
      snapshotDate: last.snapshotDate.add(Duration(days: daysAhead)),
    );
  });

  return NetWorthProjection(projectedPoints: projected);
});

// ─── idleCashDismissedProvider ────────────────────────────────────────────────

final idleCashDismissedProvider = StateProvider<bool>((ref) => false);
