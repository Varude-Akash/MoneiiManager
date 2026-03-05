import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/budgets/presentation/providers/budget_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/expense_provider.dart';
import 'package:moneii_manager/features/profile/presentation/providers/financial_account_provider.dart';

// ─── HealthScore ──────────────────────────────────────────────────────────────

class HealthScore {
  const HealthScore({
    required this.totalScore,
    required this.savingsScore,
    required this.budgetScore,
    required this.creditScore,
    required this.consistencyScore,
    required this.coverageScore,
    required this.weekStart,
  });

  final int totalScore;
  final int savingsScore;
  final int budgetScore;
  final int creditScore;
  final int consistencyScore;
  final int coverageScore;
  final DateTime weekStart;

  static final zero = HealthScore(
    totalScore: 0,
    savingsScore: 0,
    budgetScore: 0,
    creditScore: 0,
    consistencyScore: 0,
    coverageScore: 0,
    weekStart: DateTime.utc(1970),
  );
}

// ─── healthScoreProvider ──────────────────────────────────────────────────────

final healthScoreProvider = FutureProvider<HealthScore>((ref) async {
  final expenses = ref.watch(expensesProvider).valueOrNull ?? [];
  final budgetsAsync = ref.watch(budgetsProvider);
  final accountsAsync = ref.watch(financialAccountsProvider);
  final profile = ref.watch(profileProvider).valueOrNull;

  final budgets = budgetsAsync.valueOrNull ?? [];
  final accounts = accountsAsync.valueOrNull ?? [];

  final now = DateTime.now();
  final currentMonthExpenses = expenses.where((e) {
    return e.expenseDate.year == now.year &&
        e.expenseDate.month == now.month;
  }).toList();

  final monthlyExpenses = currentMonthExpenses
      .where((e) => e.transactionType == 'expense')
      .fold<double>(0, (sum, e) => sum + e.amount);
  final monthlyIncome = currentMonthExpenses
      .where((e) => e.transactionType == 'income')
      .fold<double>(0, (sum, e) => sum + e.amount);

  final savingsRate =
      monthlyIncome > 0 ? (monthlyIncome - monthlyExpenses) / monthlyIncome : 0.0;

  // ── Savings score (0-30)
  int savingsScore;
  if (monthlyIncome <= 0) {
    savingsScore = 15; // neutral if no income logged
  } else if (savingsRate >= 0.20) {
    savingsScore = 30;
  } else if (savingsRate >= 0.10) {
    savingsScore = 20;
  } else if (savingsRate > 0) {
    savingsScore = 10;
  } else {
    savingsScore = 0;
  }

  // ── Budget score (0-25)
  int budgetScore;
  if (budgets.isEmpty) {
    budgetScore = 12;
  } else {
    final progressList = ref.watch(budgetProgressProvider);
    final underBudget = progressList.where((p) => !p.isOver).length;
    final totalBudgets = budgets.length;
    budgetScore = (underBudget / totalBudgets * 25).round();
  }

  // ── Credit score (0-20)
  int creditScore;
  final creditCards =
      accounts.where((a) => a.accountType == 'credit_card').toList();
  if (creditCards.isEmpty) {
    creditScore = 20;
  } else {
    final totalLimit = creditCards.fold<double>(
        0, (sum, a) => sum + a.creditLimit);
    final totalUtilized =
        creditCards.fold<double>(0, (sum, a) => sum + a.utilizedAmount);
    final utilization = totalLimit > 0 ? totalUtilized / totalLimit : 0.0;

    if (utilization < 0.30) {
      creditScore = 20;
    } else if (utilization < 0.50) {
      creditScore = 15;
    } else if (utilization < 0.75) {
      creditScore = 8;
    } else {
      creditScore = 0;
    }
  }

  // ── Consistency score (0-15)
  // Distinct days with any transaction in the last 7 days
  final sevenDaysAgo = now.subtract(const Duration(days: 7));
  final recentExpenses =
      expenses.where((e) => e.expenseDate.isAfter(sevenDaysAgo)).toList();
  final distinctDays = recentExpenses
      .map((e) =>
          '${e.expenseDate.year}-${e.expenseDate.month}-${e.expenseDate.day}')
      .toSet()
      .length;

  int consistencyScore;
  if (distinctDays >= 6) {
    consistencyScore = 15;
  } else if (distinctDays >= 4) {
    consistencyScore = 10;
  } else if (distinctDays >= 2) {
    consistencyScore = 5;
  } else {
    consistencyScore = 0;
  }

  // ── Coverage score (0-10)
  final coverageScore = monthlyIncome >= monthlyExpenses ? 10 : 0;

  final totalScore =
      savingsScore + budgetScore + creditScore + consistencyScore + coverageScore;

  // Week start = Monday of current week
  final weekday = now.weekday; // 1=Mon, 7=Sun
  final weekStart = DateTime(
    now.year,
    now.month,
    now.day - (weekday - 1),
  );

  return HealthScore(
    totalScore: totalScore,
    savingsScore: savingsScore,
    budgetScore: budgetScore,
    creditScore: creditScore,
    consistencyScore: consistencyScore,
    coverageScore: coverageScore,
    weekStart: weekStart,
  );
});

// ─── HealthScoreSnapshot ──────────────────────────────────────────────────────

class HealthScoreSnapshot {
  const HealthScoreSnapshot({
    required this.totalScore,
    required this.weekStart,
  });

  final int totalScore;
  final DateTime weekStart;

  factory HealthScoreSnapshot.fromJson(Map<String, dynamic> json) {
    return HealthScoreSnapshot(
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      weekStart: DateTime.parse(
        json['week_start'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

// ─── healthScoreHistoryProvider ───────────────────────────────────────────────

final healthScoreHistoryProvider =
    FutureProvider<List<HealthScoreSnapshot>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('health_score_snapshots')
      .select('*')
      .eq('user_id', user.id)
      .order('week_start', ascending: false)
      .limit(8);

  return (data as List)
      .map((e) => HealthScoreSnapshot.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─── saveHealthScoreProvider ──────────────────────────────────────────────────

final saveHealthScoreProvider = FutureProvider<void>((ref) async {
  try {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final client = ref.read(supabaseClientProvider);
    final scoreAsync = ref.read(healthScoreProvider);
    final score = scoreAsync.valueOrNull;
    if (score == null) return;

    final weekStart = score.weekStart;
    final weekStartStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';

    await client.from('health_score_snapshots').upsert({
      'user_id': user.id,
      'week_start': weekStartStr,
      'total_score': score.totalScore,
      'savings_score': score.savingsScore,
      'budget_score': score.budgetScore,
      'credit_score': score.creditScore,
      'consistency_score': score.consistencyScore,
      'coverage_score': score.coverageScore,
    }, onConflict: 'user_id,week_start');
  } catch (_) {
    // Silently handle — snapshot saving is best-effort.
  }
});
