import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  final String id;
  final String userId;
  final double amount;
  final String currency;
  final int categoryId;
  final int? subcategoryId;
  final String categoryName;
  final String? subcategoryName;
  final String? description;
  final DateTime expenseDate;
  final String inputMethod;
  final String? rawTranscript;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.userId,
    required this.amount,
    this.currency = 'USD',
    required this.categoryId,
    this.subcategoryId,
    required this.categoryName,
    this.subcategoryName,
    this.description,
    required this.expenseDate,
    this.inputMethod = 'manual',
    this.rawTranscript,
    required this.createdAt,
  });

  Expense copyWith({
    String? id,
    String? userId,
    double? amount,
    String? currency,
    int? categoryId,
    int? subcategoryId,
    String? categoryName,
    String? subcategoryName,
    String? description,
    DateTime? expenseDate,
    String? inputMethod,
    String? rawTranscript,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      categoryName: categoryName ?? this.categoryName,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      description: description ?? this.description,
      expenseDate: expenseDate ?? this.expenseDate,
      inputMethod: inputMethod ?? this.inputMethod,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      categoryId: json['category_id'] as int,
      subcategoryId: json['subcategory_id'] as int?,
      categoryName:
          json['category_name'] as String? ??
          (json['categories'] != null
              ? json['categories']['name'] as String
              : 'Other'),
      subcategoryName:
          json['subcategory_name'] as String? ??
          (json['subcategory'] != null
              ? json['subcategory']['name'] as String?
              : null),
      description: json['description'] as String?,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      inputMethod: json['input_method'] as String? ?? 'manual',
      rawTranscript: json['raw_transcript'] as String?,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'currency': currency,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'description': description,
      'expense_date': expenseDate.toIso8601String().split('T')[0],
      'input_method': inputMethod,
      'raw_transcript': rawTranscript,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'amount': amount,
      'currency': currency,
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'description': description,
      'expense_date': expenseDate.toIso8601String().split('T')[0],
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, amount, categoryId, description, expenseDate];
}
