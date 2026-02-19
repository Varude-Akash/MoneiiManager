class ParsedExpense {
  final double amount;
  final String categoryName;
  final String? subcategoryName;
  final String description;
  final double confidence;
  final String rawTranscript;

  const ParsedExpense({
    required this.amount,
    required this.categoryName,
    this.subcategoryName,
    required this.description,
    required this.confidence,
    required this.rawTranscript,
  });

  ParsedExpense copyWith({
    double? amount,
    String? categoryName,
    String? subcategoryName,
    String? description,
    double? confidence,
    String? rawTranscript,
  }) {
    return ParsedExpense(
      amount: amount ?? this.amount,
      categoryName: categoryName ?? this.categoryName,
      subcategoryName: subcategoryName ?? this.subcategoryName,
      description: description ?? this.description,
      confidence: confidence ?? this.confidence,
      rawTranscript: rawTranscript ?? this.rawTranscript,
    );
  }
}
