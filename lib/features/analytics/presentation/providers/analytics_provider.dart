import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/core/providers/exchange_rate_provider.dart';
import 'package:moneii_manager/core/utils/currency_utils.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
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
    required this.preferredCurrency,
    required this.totalSpent,
    required this.totalIncome,
    required this.netFlow,
    required this.dailyAverage,
    required this.dailyIncomeAverage,
    required this.biggestExpense,
    required this.biggestExpenseAmount,
    required this.biggestIncome,
    required this.biggestIncomeAmount,
    required this.mostFrequentCategory,
    required this.categoryBreakdown,
    required this.dailySpending,
    required this.dailyIncome,
    required this.monthlyTrend,
    required this.monthlyIncomeTrend,
  });

  final DateTime selectedMonth;
  final String preferredCurrency;
  final double totalSpent;
  final double totalIncome;
  final double netFlow;
  final double dailyAverage;
  final double dailyIncomeAverage;
  final Expense? biggestExpense;
  final double biggestExpenseAmount;
  final Expense? biggestIncome;
  final double biggestIncomeAmount;
  final String mostFrequentCategory;
  final List<CategorySpend> categoryBreakdown;
  final Map<int, double> dailySpending;
  final Map<int, double> dailyIncome;
  final List<double> monthlyTrend;
  final List<double> monthlyIncomeTrend;
}

final selectedAnalyticsMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final analyticsSummaryProvider = Provider<AnalyticsSummary>((ref) {
  final selectedMonth = ref.watch(selectedAnalyticsMonthProvider);
  final expenses = ref.watch(expensesProvider).valueOrNull ?? <Expense>[];
  final categories = ref.watch(categoryByIdProvider);
  final preferredCurrency =
      ref.watch(profileProvider).valueOrNull?.currencyPreference ?? 'USD';
  final usdRates = ref.watch(supportedExchangeRatesProvider);

  final monthExpenses = expenses.where((expense) {
    return expense.expenseDate.year == selectedMonth.year &&
        expense.expenseDate.month == selectedMonth.month &&
        expense.transactionType == 'expense';
  }).toList();
  final monthIncomes = expenses.where((expense) {
    return expense.expenseDate.year == selectedMonth.year &&
        expense.expenseDate.month == selectedMonth.month &&
        expense.transactionType == 'income';
  }).toList();

  final convertedExpenseAmounts = {
    for (final expense in monthExpenses)
      expense.id: CurrencyUtils.convert(
        expense.amount,
        fromCurrency: expense.currency,
        toCurrency: preferredCurrency,
        usdRates: usdRates,
      ),
  };

  final totalSpent = convertedExpenseAmounts.values.fold<double>(
    0,
    (sum, amount) => sum + amount,
  );
  final convertedIncomeAmounts = {
    for (final income in monthIncomes)
      income.id: CurrencyUtils.convert(
        income.amount,
        fromCurrency: income.currency,
        toCurrency: preferredCurrency,
        usdRates: usdRates,
      ),
  };
  final totalIncome = convertedIncomeAmounts.values.fold<double>(
    0,
    (sum, amount) => sum + amount,
  );
  final netFlow = totalIncome - totalSpent;

  Expense? biggestExpense;
  var biggestExpenseAmount = 0.0;
  for (final expense in monthExpenses) {
    final convertedAmount =
        convertedExpenseAmounts[expense.id] ?? expense.amount;
    if (biggestExpense == null || convertedAmount > biggestExpenseAmount) {
      biggestExpense = expense;
      biggestExpenseAmount = convertedAmount;
    }
  }
  Expense? biggestIncome;
  var biggestIncomeAmount = 0.0;
  for (final income in monthIncomes) {
    final convertedAmount = convertedIncomeAmounts[income.id] ?? income.amount;
    if (biggestIncome == null || convertedAmount > biggestIncomeAmount) {
      biggestIncome = income;
      biggestIncomeAmount = convertedAmount;
    }
  }

  final groupedByCategory = <int, double>{};
  final categoryFrequency = <int, int>{};
  for (final expense in monthExpenses) {
    groupedByCategory.update(
      expense.categoryId,
      (value) =>
          value + (convertedExpenseAmounts[expense.id] ?? expense.amount),
      ifAbsent: () => convertedExpenseAmounts[expense.id] ?? expense.amount,
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
  final dailyIncome = <int, double>{
    for (var i = 1; i <= daysInMonth; i++) i: 0,
  };
  for (final expense in monthExpenses) {
    dailySpending.update(
      expense.expenseDate.day,
      (value) =>
          value + (convertedExpenseAmounts[expense.id] ?? expense.amount),
    );
  }
  for (final income in monthIncomes) {
    dailyIncome.update(
      income.expenseDate.day,
      (value) => value + (convertedIncomeAmounts[income.id] ?? income.amount),
    );
  }

  final dailyAverage = daysInMonth == 0 ? 0.0 : totalSpent / daysInMonth;
  final dailyIncomeAverage = daysInMonth == 0 ? 0.0 : totalIncome / daysInMonth;

  final monthlyTrend = List<double>.generate(6, (index) {
    final month = DateTime(
      selectedMonth.year,
      selectedMonth.month - (5 - index),
    );
    return expenses
        .where(
          (expense) =>
              expense.expenseDate.year == month.year &&
              expense.expenseDate.month == month.month &&
              expense.transactionType == 'expense',
        )
        .fold<double>(0, (sum, expense) {
          final convertedAmount = CurrencyUtils.convert(
            expense.amount,
            fromCurrency: expense.currency,
            toCurrency: preferredCurrency,
            usdRates: usdRates,
          );
          return sum + convertedAmount;
        });
  });
  final monthlyIncomeTrend = List<double>.generate(6, (index) {
    final month = DateTime(
      selectedMonth.year,
      selectedMonth.month - (5 - index),
    );
    return expenses
        .where(
          (expense) =>
              expense.expenseDate.year == month.year &&
              expense.expenseDate.month == month.month &&
              expense.transactionType == 'income',
        )
        .fold<double>(0, (sum, expense) {
          final convertedAmount = CurrencyUtils.convert(
            expense.amount,
            fromCurrency: expense.currency,
            toCurrency: preferredCurrency,
            usdRates: usdRates,
          );
          return sum + convertedAmount;
        });
  });

  return AnalyticsSummary(
    selectedMonth: selectedMonth,
    preferredCurrency: preferredCurrency,
    totalSpent: totalSpent,
    totalIncome: totalIncome,
    netFlow: netFlow,
    dailyAverage: dailyAverage,
    dailyIncomeAverage: dailyIncomeAverage,
    biggestExpense: biggestExpense,
    biggestExpenseAmount: biggestExpenseAmount,
    biggestIncome: biggestIncome,
    biggestIncomeAmount: biggestIncomeAmount,
    mostFrequentCategory: mostFrequentCategory,
    categoryBreakdown: categoryBreakdown,
    dailySpending: dailySpending,
    dailyIncome: dailyIncome,
    monthlyTrend: monthlyTrend,
    monthlyIncomeTrend: monthlyIncomeTrend,
  );
});
