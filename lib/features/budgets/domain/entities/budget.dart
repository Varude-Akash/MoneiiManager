import 'package:equatable/equatable.dart';

class Budget extends Equatable {
  const Budget({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.currency,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final int categoryId;
  final String categoryName;
  final double amount;
  final String currency;
  final bool isActive;
  final DateTime createdAt;

  factory Budget.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category_name'] as String? ??
        (json['categories'] != null
            ? json['categories']['name'] as String? ?? 'Unknown'
            : 'Unknown');
    return Budget(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as int,
      categoryName: categoryName,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'category_id': categoryId,
      'amount': amount,
      'currency': currency,
      'is_active': isActive,
    };
  }

  Budget copyWith({
    String? id,
    String? userId,
    int? categoryId,
    String? categoryName,
    double? amount,
    String? currency,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        categoryId,
        categoryName,
        amount,
        currency,
        isActive,
        createdAt,
      ];
}
