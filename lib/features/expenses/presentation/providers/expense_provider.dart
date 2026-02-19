import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/expenses/domain/entities/expense.dart';

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

class AddExpenseNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  AddExpenseNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> addExpense(Expense expense) async {
    state = const AsyncValue.loading();
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.from('expenses').insert(expense.toInsertJson());
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
