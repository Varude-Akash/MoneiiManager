import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/profile/domain/entities/financial_account.dart';

final financialAccountsProvider = FutureProvider<List<FinancialAccount>>((
  ref,
) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];

  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('financial_accounts')
      .select('*')
      .eq('user_id', user.id)
      .order('account_type', ascending: true)
      .order('is_default', ascending: false)
      .order('created_at', ascending: true);

  return (data as List)
      .map((row) => FinancialAccount.fromJson(row as Map<String, dynamic>))
      .toList();
});

class FinancialAccountActions extends StateNotifier<AsyncValue<void>> {
  FinancialAccountActions(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<void> addAccount({
    required String name,
    required String accountType,
    required bool isDefault,
    required double initialBalance,
    required double creditLimit,
    required double initialUtilizedAmount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');

      final client = _ref.read(supabaseClientProvider);

      if (isDefault) {
        await client
            .from('financial_accounts')
            .update({'is_default': false})
            .eq('user_id', user.id)
            .eq('account_type', accountType);
      }

      final initial = accountType == 'credit_card' ? 0 : initialBalance;
      final limit = accountType == 'credit_card' ? creditLimit : 0;
      final initialUtilized = accountType == 'credit_card'
          ? initialUtilizedAmount
          : 0;
      final current = accountType == 'credit_card'
          ? (limit - initialUtilized)
          : initial;

      await client.from('financial_accounts').insert({
        'user_id': user.id,
        'name': name.trim(),
        'account_type': accountType,
        'initial_balance': initial,
        'current_balance': current,
        'credit_limit': limit,
        'initial_utilized_amount': initialUtilized,
        'utilized_amount': initialUtilized,
        'is_default': isDefault,
      });

      _ref.invalidate(financialAccountsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> setDefault({
    required String accountId,
    required String accountType,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');

      final client = _ref.read(supabaseClientProvider);

      await client
          .from('financial_accounts')
          .update({'is_default': false})
          .eq('user_id', user.id)
          .eq('account_type', accountType);

      await client
          .from('financial_accounts')
          .update({'is_default': true})
          .eq('id', accountId)
          .eq('user_id', user.id);

      _ref.invalidate(financialAccountsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteAccount(String accountId) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');

      final client = _ref.read(supabaseClientProvider);
      await client
          .from('financial_accounts')
          .delete()
          .eq('id', accountId)
          .eq('user_id', user.id);

      _ref.invalidate(financialAccountsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateAccount({
    required FinancialAccount account,
    required String name,
    required bool isDefault,
    double? initialBalance,
    double? creditLimit,
    double? utilizedAmount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');

      final client = _ref.read(supabaseClientProvider);

      if (isDefault && !account.isDefault) {
        await client
            .from('financial_accounts')
            .update({'is_default': false})
            .eq('user_id', user.id)
            .eq('account_type', account.accountType);
      }

      final payload = <String, dynamic>{
        'name': name.trim(),
        'is_default': isDefault,
      };

      if (account.accountType == 'credit_card') {
        final nextLimit = creditLimit ?? account.creditLimit;
        final nextUtilized = utilizedAmount ?? account.utilizedAmount;
        payload['credit_limit'] = nextLimit;
        payload['initial_utilized_amount'] = nextUtilized;
        payload['utilized_amount'] = nextUtilized;
        payload['current_balance'] = nextLimit - nextUtilized;
      } else {
        final nextInitial = initialBalance ?? account.initialBalance;
        final netDelta = account.currentBalance - account.initialBalance;
        payload['initial_balance'] = nextInitial;
        payload['current_balance'] = nextInitial + netDelta;
      }

      await client
          .from('financial_accounts')
          .update(payload)
          .eq('id', account.id)
          .eq('user_id', user.id);

      _ref.invalidate(financialAccountsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final financialAccountActionsProvider =
    StateNotifierProvider<FinancialAccountActions, AsyncValue<void>>(
      (ref) => FinancialAccountActions(ref),
    );
