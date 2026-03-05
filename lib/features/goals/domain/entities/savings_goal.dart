import 'package:equatable/equatable.dart';

class SavingsGoal extends Equatable {
  const SavingsGoal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    required this.icon,
    required this.color,
    required this.currency,
    required this.isCompleted,
    this.linkedAccountId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final String icon;
  final String color;
  final String currency;
  final bool isCompleted;
  final String? linkedAccountId;
  final DateTime createdAt;

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0;

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String? ?? '',
      targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0,
      currentAmount: (json['current_amount'] as num?)?.toDouble() ?? 0,
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      icon: json['icon'] as String? ?? '🎯',
      color: json['color'] as String? ?? '#7C3AED',
      currency: json['currency'] as String? ?? 'USD',
      isCompleted: json['is_completed'] as bool? ?? false,
      linkedAccountId: json['linked_account_id'] as String?,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'deadline': deadline?.toIso8601String().split('T')[0],
      'icon': icon,
      'color': color,
      'currency': currency,
      'is_completed': isCompleted,
      'linked_account_id': linkedAccountId,
    };
  }

  SavingsGoal copyWith({
    String? id,
    String? userId,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    bool clearDeadline = false,
    String? icon,
    String? color,
    String? currency,
    bool? isCompleted,
    String? linkedAccountId,
    bool clearLinkedAccount = false,
    DateTime? createdAt,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      icon: icon ?? this.icon,
      color: color ?? this.color,
      currency: currency ?? this.currency,
      isCompleted: isCompleted ?? this.isCompleted,
      linkedAccountId: clearLinkedAccount
          ? null
          : (linkedAccountId ?? this.linkedAccountId),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        targetAmount,
        currentAmount,
        deadline,
        icon,
        color,
        currency,
        isCompleted,
        linkedAccountId,
        createdAt,
      ];
}
