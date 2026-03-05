import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/goals/domain/entities/savings_goal.dart';

// ─── savingsGoalsProvider ────────────────────────────────────────────────────

final savingsGoalsProvider = FutureProvider<List<SavingsGoal>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final client = ref.watch(supabaseClientProvider);

  final data = await client
      .from('savings_goals')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', ascending: false);

  return (data as List)
      .map((e) => SavingsGoal.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─── GoalActions ─────────────────────────────────────────────────────────────

class GoalActions extends StateNotifier<AsyncValue<void>> {
  GoalActions(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> addGoal(SavingsGoal goal) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');
      final client = _ref.read(supabaseClientProvider);

      await client.from('savings_goals').insert(goal.toInsertJson());
      _ref.invalidate(savingsGoalsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');
      final client = _ref.read(supabaseClientProvider);

      await client
          .from('savings_goals')
          .update({
            'name': goal.name,
            'target_amount': goal.targetAmount,
            'current_amount': goal.currentAmount,
            'deadline': goal.deadline?.toIso8601String().split('T')[0],
            'icon': goal.icon,
            'color': goal.color,
            'currency': goal.currency,
            'is_completed': goal.isCompleted,
            'linked_account_id': goal.linkedAccountId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', goal.id)
          .eq('user_id', user.id);

      _ref.invalidate(savingsGoalsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteGoal(String id) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');
      final client = _ref.read(supabaseClientProvider);

      await client
          .from('savings_goals')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      _ref.invalidate(savingsGoalsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> addContribution(String goalId, double amount) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');
      final client = _ref.read(supabaseClientProvider);

      // Fetch current goal
      final row = await client
          .from('savings_goals')
          .select('current_amount, target_amount')
          .eq('id', goalId)
          .eq('user_id', user.id)
          .single();

      final currentAmount =
          (row['current_amount'] as num?)?.toDouble() ?? 0;
      final targetAmount =
          (row['target_amount'] as num?)?.toDouble() ?? 0;
      final newAmount = currentAmount + amount;
      final isCompleted = newAmount >= targetAmount;

      await client
          .from('savings_goals')
          .update({
            'current_amount': newAmount,
            'is_completed': isCompleted,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', goalId)
          .eq('user_id', user.id);

      _ref.invalidate(savingsGoalsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final goalActionsProvider =
    StateNotifierProvider<GoalActions, AsyncValue<void>>(
  (ref) => GoalActions(ref),
);
