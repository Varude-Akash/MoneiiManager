import 'package:moneii_manager/core/constants.dart';
import 'package:moneii_manager/features/voice/domain/entities/parsed_expense.dart';

class ExpenseParserService {
  static const Map<String, int> _smallNumbers = {
    'zero': 0,
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
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  };

  ParsedExpense parse(String transcript) {
    final normalized = _normalize(transcript);
    final amount = _extractAmount(normalized);
    final description = _extractDescription(normalized);
    final expenseDate = _extractExpenseDate(normalized);
    final transactionType = _extractTransactionType(normalized);
    final paymentSource = _extractPaymentSource(normalized);
    final accountNameHint = _extractAccountNameHint(normalized);
    final category = _classifyCategory(
      normalized,
      description,
      transactionType: transactionType,
    );
    final confidence = _calculateConfidence(amount, category, description);

    return ParsedExpense(
      amount: amount,
      categoryName: category.$1,
      subcategoryName: category.$2,
      description: description.isNotEmpty ? description : transcript.trim(),
      expenseDate: expenseDate,
      transactionType: transactionType,
      paymentSource: paymentSource,
      accountNameHint: accountNameHint,
      confidence: confidence,
      rawTranscript: transcript,
    );
  }

  DateTime _extractExpenseDate(String text) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekdays = <String, int>{
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    if (RegExp(r'\byesterday\b').hasMatch(text)) {
      return today.subtract(const Duration(days: 1));
    }
    if (RegExp(r'\btoday\b').hasMatch(text)) {
      return today;
    }

    final daysAgoMatch = RegExp(r'\b(\d{1,3})\s+days?\s+ago\b').firstMatch(text);
    if (daysAgoMatch != null) {
      final days = int.tryParse(daysAgoMatch.group(1)!);
      if (days != null && days > 0) {
        return today.subtract(Duration(days: days));
      }
    }

    if (RegExp(r'\b(a|an)\s+day\s+ago\b').hasMatch(text)) {
      return today.subtract(const Duration(days: 1));
    }

    final lastWeekdayMatch = RegExp(
      r'\blast\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    ).firstMatch(text);
    if (lastWeekdayMatch != null) {
      final weekday = weekdays[lastWeekdayMatch.group(1)!];
      if (weekday != null) {
        return _previousWeekday(today, weekday);
      }
    }

    final thisWeekdayMatch = RegExp(
      r'\bthis\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
    ).firstMatch(text);
    if (thisWeekdayMatch != null) {
      final weekday = weekdays[thisWeekdayMatch.group(1)!];
      if (weekday != null) {
        final delta = weekday - today.weekday;
        return today.add(Duration(days: delta));
      }
    }

    final isoMatch = RegExp(
      r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b',
    ).firstMatch(text);
    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1)!);
      final month = int.tryParse(isoMatch.group(2)!);
      final day = int.tryParse(isoMatch.group(3)!);
      final parsed = _safeDate(year, month, day);
      if (parsed != null) return parsed;
    }

    final slashMatch = RegExp(
      r'\b(\d{1,2})/(\d{1,2})/(\d{2,4})\b',
    ).firstMatch(text);
    if (slashMatch != null) {
      final first = int.tryParse(slashMatch.group(1)!);
      final second = int.tryParse(slashMatch.group(2)!);
      var year = int.tryParse(slashMatch.group(3)!);
      if (year != null && year < 100) year += 2000;

      // Interpret as month/day/year (common in US).
      final parsed = _safeDate(year, first, second);
      if (parsed != null) return parsed;
    }

    final monthWords = <String, int>{
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };

    final monthNamePattern = RegExp(
      r'\b(\d{1,2})(?:st|nd|rd|th)?\s+'
      r'(january|february|march|april|may|june|july|august|september|october|november|december)'
      r'(?:\s+(\d{4}))?\b',
    );
    final monthNameMatch = monthNamePattern.firstMatch(text);
    if (monthNameMatch != null) {
      final day = int.tryParse(monthNameMatch.group(1)!);
      final month = monthWords[monthNameMatch.group(2)!];
      final year = int.tryParse(monthNameMatch.group(3) ?? '') ?? now.year;
      final parsed = _safeDate(year, month, day);
      if (parsed != null) return parsed;
    }

    final ordinalDayMatch = RegExp(
      r'\b(?:on\s+)?(\d{1,2})(?:st|nd|rd|th)\b',
    ).firstMatch(text);
    if (ordinalDayMatch != null) {
      final day = int.tryParse(ordinalDayMatch.group(1)!);
      final parsed = _safeDate(now.year, now.month, day);
      if (parsed != null) return parsed;
    }

    return today;
  }

  DateTime _previousWeekday(DateTime from, int targetWeekday) {
    var daysBack = (from.weekday - targetWeekday + 7) % 7;
    if (daysBack == 0) daysBack = 7;
    return from.subtract(Duration(days: daysBack));
  }

  DateTime? _safeDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;
    if (year < 2000 || year > 2100) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;

    final candidate = DateTime(year, month, day);
    if (candidate.year != year ||
        candidate.month != month ||
        candidate.day != day) {
      return null;
    }
    return candidate;
  }

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s\$\.,/\-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _extractTransactionType(String text) {
    if (RegExp(
      r'\b(salary|paycheck|credited|received|income|earned|bonus|freelance)\b',
    ).hasMatch(text)) {
      return 'income';
    }
    if (RegExp(r'\b(self transfer|transfer|transferred|moved)\b').hasMatch(text)) {
      return 'transfer';
    }
    if (RegExp(
      r'\b(credit card bill|card bill|credit card payment|cc bill)\b',
    ).hasMatch(text)) {
      return 'credit_card_payment';
    }
    return 'expense';
  }

  String _extractPaymentSource(String text) {
    if (RegExp(r'\b(credit card|cc card)\b').hasMatch(text)) {
      return 'credit_card';
    }
    if (RegExp(r'\b(debit card)\b').hasMatch(text)) {
      return 'bank_account';
    }
    if (RegExp(r'\b(wallet|paytm wallet|amazon pay wallet)\b').hasMatch(text)) {
      return 'wallet';
    }
    if (RegExp(r'\b(upi|gpay|google pay|phonepe|paytm)\b').hasMatch(text)) {
      return 'bank_account';
    }
    if (RegExp(r'\b(bank|account)\b').hasMatch(text)) {
      return 'bank_account';
    }
    if (RegExp(r'\b(cash)\b').hasMatch(text)) {
      return 'cash';
    }
    return 'cash';
  }

  String? _extractAccountNameHint(String text) {
    final match = RegExp(
      r'\b(?:in|into|to|from)\s+(?:my\s+)?([a-z0-9 ]{2,40})\s+'
      r'(?:bank account|account|credit card|card|wallet)\b',
    ).firstMatch(text);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value.replaceAll(RegExp(r'\s+'), ' ');
  }

  double _extractAmount(String text) {
    final scaledNumericAmount = _extractScaledNumericAmount(text);
    if (scaledNumericAmount > 0) return scaledNumericAmount;

    const amountPattern = r'(\d+(?:,\d{3})*(?:\.\d{1,2})?)';
    final patterns = [
      RegExp(r'\$\s*' + amountPattern),
      RegExp(
        amountPattern + r'\s*(?:dollars?|bucks?|usd|rupees?|inr|rs\.?)',
      ),
      RegExp(
        r'(?:inr|rs\.?)\s*' + amountPattern,
      ),
      RegExp(
        r'(?:spent|paid|cost|bought)\s+' + amountPattern,
      ),
      RegExp(r'\b' + amountPattern + r'\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final raw = match.group(1)?.replaceAll(',', '');
        final value = raw == null ? null : double.tryParse(raw);
        if (value != null && value > 0) return value;
      }
    }

    final wordsAmount = _extractWordsAmount(text);
    if (wordsAmount > 0) return wordsAmount;

    return 0.0;
  }

  double _extractScaledNumericAmount(String text) {
    final match = RegExp(
      r'\b(\d+(?:\.\d+)?)\s*(lakh|lac|crore|thousand|million)\b',
    ).firstMatch(text);
    if (match == null) return 0.0;

    final number = double.tryParse(match.group(1)!);
    final unit = match.group(2);
    if (number == null || unit == null) return 0.0;

    final multiplier = switch (unit) {
      'thousand' => 1000.0,
      'lakh' || 'lac' => 100000.0,
      'million' => 1000000.0,
      'crore' => 10000000.0,
      _ => 1.0,
    };

    return number * multiplier;
  }

  double _extractWordsAmount(String text) {
    final words = text.split(' ');
    var total = 0.0;
    var current = 0.0;
    const scaleWords = <String, double>{
      'hundred': 100,
      'thousand': 1000,
      'lakh': 100000,
      'lac': 100000,
      'million': 1000000,
      'crore': 10000000,
    };

    for (final word in words) {
      if (_smallNumbers.containsKey(word)) {
        current += _smallNumbers[word]!.toDouble();
      } else if (scaleWords.containsKey(word)) {
        final scale = scaleWords[word]!;
        if (scale == 100) {
          current = current == 0 ? 100 : current * 100;
        } else {
          final base = current == 0 ? 1 : current;
          total += base * scale;
          current = 0;
        }
      }
    }

    final result = total + current;
    return result;
  }

  String _extractDescription(String text) {
    final tagged = RegExp(r'(?:on|for|at)\s+(.+)').firstMatch(text);
    if (tagged != null) {
      final value = _cleanDescription(tagged.group(1)!);
      if (value.isNotEmpty) return value;
    }

    return _cleanDescription(
      text
          .replaceAll(
            RegExp(
              r'\b(?:spent|paid|cost|bought|dollars?|bucks?|usd|rupees?|inr|rs)\b',
            ),
            '',
          )
          .replaceAll(RegExp(r'\$?\d+(?:,\d{3})*(?:\.\d{1,2})?'), ''),
    );
  }

  String _cleanDescription(String value) {
    return value
        .replaceAll(
          RegExp(
            r'\b(?:today|yesterday|last|this|monday|tuesday|wednesday|thursday|friday|saturday|sunday|ago)\b',
          ),
          '',
        )
        .replaceAll(RegExp(r'\b\d{1,3}\s+days?\b'), '')
        .replaceAll(RegExp(r'\b\d{4}-\d{1,2}-\d{1,2}\b'), '')
        .replaceAll(RegExp(r'\b\d{1,2}/\d{1,2}/\d{2,4}\b'), '')
        .replaceAll(RegExp(r'\b\d{1,2}(?:st|nd|rd|th)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^(on|for|at)\s+'), '')
        .replaceAll(RegExp(r'^[,.\-\s]+'), '')
        .replaceAll(RegExp(r'[,.\-\s]+$'), '')
        .trim();
  }

  (String, String?) _classifyCategory(
    String text,
    String description, {
    required String transactionType,
  }) {
    if (transactionType == 'income') {
      return ('Income', null);
    }
    if (transactionType == 'transfer' ||
        transactionType == 'credit_card_payment') {
      return ('Other', null);
    }

    final combined = '$text $description';
    String bestCategory = 'Other';
    String? bestSubcategory;
    int bestScore = 0;

    for (final category in AppCategories.all) {
      var score = 0;
      String? sub;

      for (final keyword in category.keywords) {
        final pattern = RegExp('\\b${RegExp.escape(keyword.toLowerCase())}\\b');
        if (pattern.hasMatch(combined)) {
          score += 2;
        }
      }

      for (final subcategory in category.subcategories) {
        final pattern = RegExp(
          '\\b${RegExp.escape(subcategory.toLowerCase())}\\b',
        );
        if (pattern.hasMatch(combined)) {
          score += 3;
          sub = subcategory;
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
    var score = 0.0;
    if (amount > 0) score += 0.5;
    if (category.$1 != 'Other') score += 0.3;
    if (description.isNotEmpty) score += 0.2;
    return score.clamp(0.0, 1.0);
  }
}
