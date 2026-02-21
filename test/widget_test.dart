import 'package:flutter_test/flutter_test.dart';
import 'package:moneii_manager/features/voice/data/services/expense_parser_service.dart';

void main() {
  test('voice parser extracts amount and category', () {
    final parser = ExpenseParserService();
    final parsed = parser.parse('Spent \$12 on lunch at subway');

    expect(parsed.amount, 12);
    expect(parsed.categoryName, 'Food & Dining');
  });

  test('voice parser extracts plain 4 digit rupee amount', () {
    final parser = ExpenseParserService();
    final parsed = parser.parse(
      'I paid gym membership of rupees 1500 this Tuesday',
    );

    expect(parsed.amount, 1500);
  });

  test('voice parser extracts INR prefix amount', () {
    final parser = ExpenseParserService();
    final parsed = parser.parse('Paid INR 1500 for gym');

    expect(parsed.amount, 1500);
  });

  test('voice parser detects income intent and source', () {
    final parser = ExpenseParserService();
    final parsed = parser.parse('Salary of 45000 credited to bank account');

    expect(parsed.transactionType, 'income');
    expect(parsed.paymentSource, 'bank_account');
    expect(parsed.amount, 45000);
  });

  test('voice parser extracts Indian lakh amount words', () {
    final parser = ExpenseParserService();
    final parsed = parser.parse('One lakh salary credited in my bank account');

    expect(parsed.transactionType, 'income');
    expect(parsed.paymentSource, 'bank_account');
    expect(parsed.amount, 100000);
  });

  test('voice parser extracts numeric lakh amount', () {
    final parser = ExpenseParserService();
    final parsed = parser.parse('1 lakh rupees salary is credited');

    expect(parsed.transactionType, 'income');
    expect(parsed.amount, 100000);
  });

  test('voice parser maps upi to bank account source', () {
    final parser = ExpenseParserService();
    final parsed = parser.parse('Paid 250 via upi for lunch');

    expect(parsed.paymentSource, 'bank_account');
  });

  test('voice parser detects wallet source', () {
    final parser = ExpenseParserService();
    final parsed = parser.parse('Spent 100 from my paytm wallet');

    expect(parsed.paymentSource, 'wallet');
  });
}
