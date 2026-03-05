import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
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
