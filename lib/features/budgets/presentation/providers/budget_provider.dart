import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/budgets/domain/entities/budget.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/expense_provider.dart';

// ─── BudgetProgress ───────────────────────────────────────────────────────────

class BudgetProgress {
  const BudgetProgress({
    required this.budget,
    required this.spentAmount,
  });

  final Budget budget;
  final double spentAmount;

  double get percentage =>
      budget.amount > 0 ? (spentAmount / budget.amount).clamp(0.0, 2.0) : 0;

  bool get isWarning => percentage >= 0.8 && percentage < 1.0;
  bool get isOver => percentage >= 1.0;
}

// ─── budgetsProvider ─────────────────────────────────────────────────────────

final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('budgets')
      .select('*, categories(name)')
      .eq('user_id', user.id)
      .eq('is_active', true);

  return (data as List)
      .map((e) => Budget.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─── BudgetActions ───────────────────────────────────────────────────────────

class BudgetActions extends StateNotifier<AsyncValue<void>> {
  BudgetActions(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> upsert(Budget budget) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');
      final client = _ref.read(supabaseClientProvider);

      final payload = {
        'user_id': user.id,
        'category_id': budget.categoryId,
        'amount': budget.amount,
        'currency': budget.currency,
        'is_active': budget.isActive,
      };

      // If we have an id (not empty), update; otherwise insert.
      if (budget.id.isNotEmpty) {
        await client
            .from('budgets')
            .upsert({...payload, 'id': budget.id})
            .eq('id', budget.id)
            .eq('user_id', user.id);
      } else {
        await client.from('budgets').insert(payload);
      }

      _ref.invalidate(budgetsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> delete(String budgetId) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');
      final client = _ref.read(supabaseClientProvider);

      await client
          .from('budgets')
          .delete()
          .eq('id', budgetId)
          .eq('user_id', user.id);

      _ref.invalidate(budgetsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final budgetActionsProvider =
    StateNotifierProvider<BudgetActions, AsyncValue<void>>(
  (ref) => BudgetActions(ref),
);

// ─── budgetProgressProvider ───────────────────────────────────────────────────

final budgetProgressProvider = Provider<List<BudgetProgress>>((ref) {
  final budgetsAsync = ref.watch(budgetsProvider);
  final expensesAsync = ref.watch(expensesProvider);

  final budgets = budgetsAsync.valueOrNull ?? [];
  final expenses = expensesAsync.valueOrNull ?? [];

  if (budgets.isEmpty) return [];

  final now = DateTime.now();
  final currentMonthExpenses = expenses.where((e) {
    return e.transactionType == 'expense' &&
        e.expenseDate.year == now.year &&
        e.expenseDate.month == now.month;
  }).toList();

  return budgets.map((budget) {
    final spent = currentMonthExpenses
        .where((e) => e.categoryId == budget.categoryId)
        .fold<double>(0.0, (sum, e) => sum + e.amount);

    return BudgetProgress(budget: budget, spentAmount: spent);
  }).toList();
});

// ─── overBudgetAlertsProvider ─────────────────────────────────────────────────

final overBudgetAlertsProvider = Provider<List<BudgetProgress>>((ref) {
  final progress = ref.watch(budgetProgressProvider);
  return progress.where((p) => p.isWarning || p.isOver).toList();
});
