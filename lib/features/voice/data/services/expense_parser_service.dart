import 'package:moneii_manager/core/constants.dart';
import 'package:moneii_manager/features/voice/domain/entities/parsed_expense.dart';

class ExpenseParserService {
  static const Map<String, int> _wordNumbers = {
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
  };

  ParsedExpense parse(String transcript) {
    final normalized = _normalize(transcript);
    final amount = _extractAmount(normalized);
    final description = _extractDescription(normalized);
    final category = _classifyCategory(normalized, description);
    final confidence = _calculateConfidence(amount, category, description);

    return ParsedExpense(
      amount: amount,
      categoryName: category.$1,
      subcategoryName: category.$2,
      description: description.isNotEmpty ? description : transcript.trim(),
      confidence: confidence,
      rawTranscript: transcript,
    );
  }

  String _normalize(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'[^\w\s\$\.]'), ' ').trim();

  double _extractAmount(String text) {
    final patterns = [
      RegExp(r'\$\s*(\d+(?:\.\d{1,2})?)'),
      RegExp(r'(\d+(?:\.\d{1,2})?)\s*(?:dollars?|bucks?|usd)'),
      RegExp(r'(?:spent|paid|cost|bought)\s+(\d+(?:\.\d{1,2})?)'),
      RegExp(r'(\d+(?:\.\d{1,2})?)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final value = double.tryParse(match.group(1)!);
        if (value != null && value > 0) return value;
      }
    }

    for (final entry in _wordNumbers.entries) {
      if (text.contains(entry.key)) return entry.value.toDouble();
    }
    return 0.0;
  }

  String _extractDescription(String text) {
    final match = RegExp(r'(?:on|for|at|bought|got)\s+(.+)').firstMatch(text);
    if (match != null) {
      final cleaned = match
          .group(1)!
          .replaceAll(RegExp(r'\d+(?:\.\d{1,2})?'), '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      if (cleaned.length > 1) return cleaned;
    }

    return text
        .replaceAll(RegExp(r'\b(?:spent|paid|cost|dollars?|bucks?|usd)\b'), '')
        .replaceAll(RegExp(r'[\$\d\.]+'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  (String, String?) _classifyCategory(String text, String description) {
    final combined = '$text $description';
    String bestCategory = 'Other';
    String? bestSubcategory;
    int bestScore = 0;

    for (final category in AppCategories.all) {
      int score = 0;
      String? sub;

      for (final keyword in category.keywords) {
        if (combined.contains(keyword)) score += 2;
      }
      for (final s in category.subcategories) {
        if (combined.contains(s.toLowerCase())) {
          score += 3;
          sub = s;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestCategory = category.name;
        bestSubcategory = sub;
      }
    }
    return (bestCategory, bestSubcategory);
  }

  double _calculateConfidence(
    double amount,
    (String, String?) category,
    String description,
  ) {
    double score = 0.0;
    if (amount > 0) score += 0.5;
    if (category.$1 != 'Other') score += 0.3;
    if (description.isNotEmpty) score += 0.2;
    return score.clamp(0.0, 1.0);
  }
}
