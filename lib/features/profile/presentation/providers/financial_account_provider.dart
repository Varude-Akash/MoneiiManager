import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/core/constants.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/profile/domain/entities/financial_account.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        final targetBalance = initialBalance ?? account.currentBalance;
        final correctionDelta = targetBalance - account.currentBalance;

        // Do not rewrite old transaction effects. Record manual balance edits as
        // a new correction transaction so history remains auditable.
        if (correctionDelta.abs() >= 0.01) {
          final correctionCategoryId = await _resolveBalanceCorrectionCategoryId(
            client,
          );
          final profile = _ref.read(profileProvider).valueOrNull;
          final currency = profile?.currencyPreference ?? AppConstants.defaultCurrency;
          final transactionType = correctionDelta > 0 ? 'income' : 'expense';
          final paymentSource = _paymentSourceForAccountType(account.accountType);

          await client.from('expenses').insert({
            'user_id': user.id,
            'amount': correctionDelta.abs(),
            'currency': currency,
            'category_id': correctionCategoryId,
            'description': 'Balance correction',
            'expense_date': DateTime.now().toIso8601String().split('T')[0],
            'transaction_type': transactionType,
            'payment_source': paymentSource,
            'account_id': account.id,
            'input_method': 'manual',
          });
        }
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

  Future<int> _resolveBalanceCorrectionCategoryId(SupabaseClient client) async {
    final rows = await client.from('categories').select('id,name,parent_id');
    final data = (rows as List).whereType<Map<String, dynamic>>().toList();
    if (data.isEmpty) {
      throw Exception('No categories found. Seed categories before editing balance.');
    }

    Map<String, dynamic>? otherRoot;
    Map<String, dynamic>? firstRoot;
    for (final row in data) {
      final parentId = row['parent_id'];
      if (parentId == null && firstRoot == null) {
        firstRoot = row;
      }
      final name = (row['name'] as String?)?.trim().toLowerCase();
      if (parentId == null && name == 'other') {
        otherRoot = row;
        break;
      }
    }

    final selected = otherRoot ?? firstRoot ?? data.first;
    final id = selected['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    throw Exception('Invalid category id for balance correction.');
  }

  String _paymentSourceForAccountType(String accountType) {
    return switch (accountType) {
      'bank_account' => 'bank_account',
      'wallet' => 'wallet',
      'credit_card' => 'credit_card',
      _ => 'cash',
    };
  }
}

final financialAccountActionsProvider =
    StateNotifierProvider<FinancialAccountActions, AsyncValue<void>>(
      (ref) => FinancialAccountActions(ref),
    );
