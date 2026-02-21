import 'package:equatable/equatable.dart';

class FinancialAccount extends Equatable {
  const FinancialAccount({
    required this.id,
    required this.userId,
    required this.name,
    required this.accountType,
    required this.initialBalance,
    required this.currentBalance,
    required this.creditLimit,
    required this.initialUtilizedAmount,
    required this.utilizedAmount,
    required this.isDefault,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String accountType; // bank_account | credit_card | wallet
  final double initialBalance;
  final double currentBalance;
  final double creditLimit;
  final double initialUtilizedAmount;
  final double utilizedAmount;
  final bool isDefault;
  final DateTime createdAt;

  factory FinancialAccount.fromJson(Map<String, dynamic> json) {
    return FinancialAccount(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      accountType: json['account_type'] as String? ?? 'bank_account',
      initialBalance: (json['initial_balance'] as num?)?.toDouble() ?? 0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
      initialUtilizedAmount:
          (json['initial_utilized_amount'] as num?)?.toDouble() ?? 0,
      utilizedAmount: (json['utilized_amount'] as num?)?.toDouble() ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    accountType,
    initialBalance,
    currentBalance,
    creditLimit,
    initialUtilizedAmount,
    utilizedAmount,
    isDefault,
    createdAt,
  ];
}
