import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/expenses/domain/entities/expense.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/category_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/expense_provider.dart';

class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.total,
  });

  final int categoryId;
  final String categoryName;
  final double total;
}

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.selectedMonth,
    required this.totalSpent,
    required this.dailyAverage,
    required this.biggestExpense,
    required this.mostFrequentCategory,
    required this.categoryBreakdown,
    required this.dailySpending,
    required this.monthlyTrend,
  });

  final DateTime selectedMonth;
  final double totalSpent;
  final double dailyAverage;
  final Expense? biggestExpense;
  final String mostFrequentCategory;
  final List<CategorySpend> categoryBreakdown;
  final Map<int, double> dailySpending;
  final List<double> monthlyTrend;
}

final selectedAnalyticsMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final analyticsSummaryProvider = Provider<AnalyticsSummary>((ref) {
  final selectedMonth = ref.watch(selectedAnalyticsMonthProvider);
  final expenses = ref.watch(expensesProvider).valueOrNull ?? <Expense>[];
  final categories = ref.watch(categoryByIdProvider);

  final monthExpenses = expenses.where((expense) {
    return expense.expenseDate.year == selectedMonth.year &&
        expense.expenseDate.month == selectedMonth.month;
  }).toList();

  final totalSpent = monthExpenses.fold<double>(
    0,
    (sum, expense) => sum + expense.amount,
  );
  final biggestExpense = monthExpenses.isEmpty
      ? null
      : (monthExpenses..sort((a, b) => b.amount.compareTo(a.amount))).first;

  final groupedByCategory = <int, double>{};
  final categoryFrequency = <int, int>{};
  for (final expense in monthExpenses) {
    groupedByCategory.update(
      expense.categoryId,
      (value) => value + expense.amount,
      ifAbsent: () => expense.amount,
    );
    categoryFrequency.update(
      expense.categoryId,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }

  final categoryBreakdown =
      groupedByCategory.entries
          .map(
            (entry) => CategorySpend(
              categoryId: entry.key,
              categoryName: categories[entry.key]?.name ?? 'Other',
              total: entry.value,
            ),
          )
          .toList()
        ..sort((a, b) => b.total.compareTo(a.total));

  var mostFrequentCategory = 'None';
  if (categoryFrequency.isNotEmpty) {
    final top = categoryFrequency.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    mostFrequentCategory = categories[top.key]?.name ?? 'Other';
  }

  final daysInMonth = DateTime(
    selectedMonth.year,
    selectedMonth.month + 1,
    0,
  ).day;
  final dailySpending = <int, double>{
    for (var i = 1; i <= daysInMonth; i++) i: 0,
  };
  for (final expense in monthExpenses) {
    dailySpending.update(
      expense.expenseDate.day,
      (value) => value + expense.amount,
    );
  }

  final dailyAverage = daysInMonth == 0 ? 0.0 : totalSpent / daysInMonth;

  final monthlyTrend = List<double>.generate(6, (index) {
    final month = DateTime(
      selectedMonth.year,
      selectedMonth.month - (5 - index),
    );
    return expenses
        .where(
          (expense) =>
              expense.expenseDate.year == month.year &&
              expense.expenseDate.month == month.month,
        )
        .fold<double>(0, (sum, expense) => sum + expense.amount);
  });

  return AnalyticsSummary(
    selectedMonth: selectedMonth,
    totalSpent: totalSpent,
    dailyAverage: dailyAverage,
    biggestExpense: biggestExpense,
    mostFrequentCategory: mostFrequentCategory,
    categoryBreakdown: categoryBreakdown,
    dailySpending: dailySpending,
    monthlyTrend: monthlyTrend,
  );
});
