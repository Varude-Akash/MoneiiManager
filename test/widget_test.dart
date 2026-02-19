import 'package:flutter_test/flutter_test.dart';
import 'package:moneii_manager/features/voice/data/services/expense_parser_service.dart';

void main() {
  test('voice parser extracts amount and category', () {
    final parser = ExpenseParserService();
    final parsed = parser.parse('Spent \$12 on lunch at subway');

    expect(parsed.amount, 12);
    expect(parsed.categoryName, 'Food & Dining');
  });
}
