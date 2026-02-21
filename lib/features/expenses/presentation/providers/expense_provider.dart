import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/expenses/domain/entities/expense.dart';
import 'package:moneii_manager/features/profile/presentation/providers/financial_account_provider.dart';

final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('expenses')
      .select('*')
      .eq('user_id', user.id)
      .order('expense_date', ascending: false)
      .order('created_at', ascending: false);

  return (data as List).map((e) => Expense.fromJson(e)).toList();
});

Future<void> _recalculateAccountBalances(Ref ref) async {
  final user = ref.read(authStateProvider).valueOrNull;
  if (user == null) return;

  final client = ref.read(supabaseClientProvider);
  final accountsData = await client
      .from('financial_accounts')
      .select(
        'id, account_type, initial_balance, credit_limit, initial_utilized_amount',
      )
      .eq('user_id', user.id);

  final expensesData = await client
      .from('expenses')
      .select('account_id, destination_account_id, amount, transaction_type')
      .eq('user_id', user.id)
      .or('account_id.not.is.null,destination_account_id.not.is.null');

  final accountRows = (accountsData as List).whereType<Map<String, dynamic>>();
  final expenseRows = (expensesData as List).whereType<Map<String, dynamic>>();
  final accountById = <String, Map<String, dynamic>>{
    for (final row in accountRows)
      if (row['id'] is String) row['id'] as String: row,
  };

  final cashFlowDeltas = <String, double>{};
  final utilizationDeltas = <String, double>{};

  void applyOutflow(String accountId, double amount) {
    final account = accountById[accountId];
    if (account == null) return;
    final type = account['account_type'] as String? ?? 'bank_account';
    if (type == 'credit_card') {
      utilizationDeltas.update(
        accountId,
        (v) => v + amount,
        ifAbsent: () => amount,
      );
    } else {
      cashFlowDeltas.update(accountId, (v) => v - amount, ifAbsent: () => -amount);
    }
  }

  void applyInflow(String accountId, double amount) {
    final account = accountById[accountId];
    if (account == null) return;
    final type = account['account_type'] as String? ?? 'bank_account';
    if (type == 'credit_card') {
      utilizationDeltas.update(
        accountId,
        (v) => v - amount,
        ifAbsent: () => -amount,
      );
    } else {
      cashFlowDeltas.update(accountId, (v) => v + amount, ifAbsent: () => amount);
    }
  }

  for (final row in expenseRows) {
    final accountId = row['account_id'] as String?;
    final destinationAccountId = row['destination_account_id'] as String?;
    final amount = (row['amount'] as num?)?.toDouble() ?? 0;
    final type = row['transaction_type'] as String? ?? 'expense';
    switch (type) {
      case 'income':
        if (accountId != null) {
          applyInflow(accountId, amount);
        }
        break;
      case 'transfer':
      case 'credit_card_payment':
        if (accountId != null) {
          applyOutflow(accountId, amount);
        }
        if (destinationAccountId != null) {
          applyInflow(destinationAccountId, amount);
        }
        break;
      case 'expense':
      default:
        if (accountId != null) {
          applyOutflow(accountId, amount);
        }
    }
  }

  for (final account in accountRows) {
    final id = account['id'] as String?;
    if (id == null) continue;
    final accountType = account['account_type'] as String? ?? 'bank_account';
    final initial = (account['initial_balance'] as num?)?.toDouble() ?? 0;
    final creditLimit = (account['credit_limit'] as num?)?.toDouble() ?? 0;
    final initialUtilized =
        (account['initial_utilized_amount'] as num?)?.toDouble() ?? 0;
    final current = initial + (cashFlowDeltas[id] ?? 0);
    final utilized = initialUtilized + (utilizationDeltas[id] ?? 0);
    final updatePayload = accountType == 'credit_card'
        ? {
            'utilized_amount': utilized,
            'current_balance': creditLimit - utilized,
            'updated_at': DateTime.now().toIso8601String(),
          }
        : {
            'current_balance': current,
            'updated_at': DateTime.now().toIso8601String(),
          };
    await client
        .from('financial_accounts')
        .update(updatePayload)
        .eq('id', id)
        .eq('user_id', user.id);
  }

  ref.invalidate(financialAccountsProvider);
}

class AddExpenseNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  AddExpenseNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addExpense(Expense expense) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.from('expenses').insert(expense.toInsertJson());
      await _recalculateAccountBalances(_ref);
      _ref.invalidate(expensesProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final addExpenseProvider =
    StateNotifierProvider<AddExpenseNotifier, AsyncValue<void>>(
      (ref) => AddExpenseNotifier(ref),
    );

class DeleteExpenseNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  DeleteExpenseNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> deleteExpense(String id) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.from('expenses').delete().eq('id', id);
      await _recalculateAccountBalances(_ref);
      _ref.invalidate(expensesProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final deleteExpenseProvider =
    StateNotifierProvider<DeleteExpenseNotifier, AsyncValue<void>>(
      (ref) => DeleteExpenseNotifier(ref),
    );

class UpdateExpenseNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  UpdateExpenseNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> updateExpense(Expense expense) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      await client
          .from('expenses')
          .update(expense.toUpdateJson())
          .eq('id', expense.id);
      await _recalculateAccountBalances(_ref);
      _ref.invalidate(expensesProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final updateExpenseProvider =
    StateNotifierProvider<UpdateExpenseNotifier, AsyncValue<void>>(
      (ref) => UpdateExpenseNotifier(ref),
    );
