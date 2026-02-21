class ParsedExpense {
  final double amount;
  final String categoryName;
  final String? subcategoryName;
  final String description;
  final DateTime expenseDate;
  final String transactionType;
  final String paymentSource;
  final String? accountNameHint;
  final double confidence;
  final String rawTranscript;

  const ParsedExpense({
    required this.amount,
    required this.categoryName,
    this.subcategoryName,
    required this.description,
    required this.expenseDate,
    this.transactionType = 'expense',
    this.paymentSource = 'cash',
    this.accountNameHint,
    required this.confidence,
    required this.rawTranscript,
  });

  ParsedExpense copyWith({
    double? amount,
    String? categoryName,
    String? subcategoryName,
    String? description,
    DateTime? expenseDate,
    String? transactionType,
    String? paymentSource,
    String? accountNameHint,
    double? confidence,
    String? rawTranscript,
  }) {
    return ParsedExpense(
      amount: amount ?? this.amount,
      categoryName: categoryName ?? this.categoryName,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      description: description ?? this.description,
      expenseDate: expenseDate ?? this.expenseDate,
      transactionType: transactionType ?? this.transactionType,
      paymentSource: paymentSource ?? this.paymentSource,
      accountNameHint: accountNameHint ?? this.accountNameHint,
      confidence: confidence ?? this.confidence,
      rawTranscript: rawTranscript ?? this.rawTranscript,
    );
  }
}
