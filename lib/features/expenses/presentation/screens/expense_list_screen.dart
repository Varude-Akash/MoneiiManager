import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/utils/currency_utils.dart';
import 'package:moneii_manager/core/utils/date_utils.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/expenses/domain/entities/category.dart';
import 'package:moneii_manager/features/expenses/domain/entities/expense.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/category_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/expense_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:moneii_manager/features/voice/presentation/screens/voice_input_sheet.dart';
import 'package:moneii_manager/shared/widgets/glass_card.dart';
import 'package:moneii_manager/shared/widgets/shimmer_skeleton.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final categoryById = ref.watch(categoryByIdProvider);

    return Scaffold(
      floatingActionButton:
          GestureDetector(
                onLongPress: () => _showAddOptions(context),
                child: FloatingActionButton(
                  heroTag: 'home_mic_fab',
                  onPressed: () => _openVoiceAdd(context),
                  child: const Icon(Icons.mic_rounded),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.08, 1.08),
                duration: 1400.ms,
                curve: Curves.easeInOut,
              ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(expensesProvider);
            ref.invalidate(categoryByIdProvider);
          },
          child: expensesAsync.when(
            loading: () => const ExpenseListShimmer(),
            error: (error, _) => _ErrorState(
              message: error.toString(),
              onRetry: () => ref.invalidate(expensesProvider),
            ),
            data: (expenses) {
              if (expenses.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _Header(
                      expenses: expenses,
                      profileName: profile?.displayName,
                    ),
                    const SizedBox(height: 72),
                    const _EmptyState(),
                  ],
                );
              }

              final grouped = _groupExpensesByDate(expenses);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                children: [
                  _Header(
                    expenses: expenses,
                    profileName: profile?.displayName,
                  ),
                  const SizedBox(height: 16),
                  ...grouped.entries.map((entry) {
                    return _ExpenseGroup(
                      date: entry.key,
                      expenses: entry.value,
                      categoryById: categoryById,
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Map<DateTime, List<Expense>> _groupExpensesByDate(List<Expense> expenses) {
    final map = <DateTime, List<Expense>>{};

    for (final expense in expenses) {
      final key = DateTime(
        expense.expenseDate.year,
        expense.expenseDate.month,
        expense.expenseDate.day,
      );
      map.putIfAbsent(key, () => []).add(expense);
    }

    final sortedKeys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final key in sortedKeys) key: map[key]!};
  }

  static Future<void> _openVoiceAdd(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final parsed = await showVoiceInputSheet(context);
    if (!context.mounted || parsed == null) return;

    context.push(
      '/add-expense',
      extra: AddExpenseInitialData.fromParsed(parsed),
    );
  }

  static Future<void> _showAddOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.mic_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text('Speak'),
                  subtitle: const Text('Use voice to add expense'),
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    Navigator.pop(bottomSheetContext);
                    await _openVoiceAdd(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.keyboard_alt_rounded),
                  title: const Text('Type'),
                  subtitle: const Text('Enter expense manually'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(bottomSheetContext);
                    context.push('/add-expense');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.expenses, required this.profileName});

  final List<Expense> expenses;
  final String? profileName;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthExpenses = expenses
        .where(
          (expense) =>
              expense.expenseDate.year == now.year &&
              expense.expenseDate.month == now.month,
        )
        .toList();

    final monthTotal = monthExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hey, ${profileName?.trim().isNotEmpty == true ? profileName : 'there'}!',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),
        const SizedBox(height: 2),
        Text(
          AppDateUtils.formatMonth(now),
          style: const TextStyle(color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 14),
        GlassCard(
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Spent this month',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: monthTotal),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Text(
                    CurrencyUtils.format(value),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              SizedBox(height: 56, child: _MiniSparkline(expenses: expenses)),
            ],
          ),
        ).animate().fadeIn(delay: 130.ms).slideY(begin: 0.1),
      ],
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final points = List.generate(7, (index) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - index));
      final dailyTotal = expenses
          .where(
            (expense) =>
                expense.expenseDate.year == day.year &&
                expense.expenseDate.month == day.month &&
                expense.expenseDate.day == day.day,
          )
          .fold<double>(0, (sum, expense) => sum + expense.amount);
      return FlSpot(index.toDouble(), dailyTotal);
    });

    final maxY = points.fold<double>(
      0,
      (max, spot) => spot.y > max ? spot.y : max,
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: maxY == 0 ? 100 : maxY * 1.2,
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.accent,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.28),
                  AppColors.accent.withValues(alpha: 0.01),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseGroup extends ConsumerWidget {
  const _ExpenseGroup({
    required this.date,
    required this.expenses,
    required this.categoryById,
  });

  final DateTime date;
  final List<Expense> expenses;
  final Map<int, ExpenseCategory> categoryById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              AppDateUtils.formatGroupHeader(date),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...expenses.map((expense) {
            final category = categoryById[expense.categoryId];
            final categoryName = category?.name ?? expense.categoryName;
            final subcategoryName =
                categoryById[expense.subcategoryId]?.name ??
                expense.subcategoryName;
            final amount = CurrencyUtils.format(
              expense.amount,
              currency: expense.currency,
            );

            return Dismissible(
              key: ValueKey(expense.id),
              background: _DismissBackground(
                icon: Icons.edit_rounded,
                label: 'Edit',
                alignment: Alignment.centerLeft,
                color: AppColors.accent,
              ),
              secondaryBackground: _DismissBackground(
                icon: Icons.delete_rounded,
                label: 'Delete',
                alignment: Alignment.centerRight,
                color: AppColors.error,
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  context.push('/add-expense', extra: expense);
                  return false;
                }
                return true;
              },
              onDismissed: (direction) async {
                HapticFeedback.lightImpact();
                await ref
                    .read(deleteExpenseProvider.notifier)
                    .deleteExpense(expense.id);
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Expense deleted'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        ref
                            .read(addExpenseProvider.notifier)
                            .addExpense(expense);
                      },
                    ),
                  ),
                );
              },
              child: GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            (category?.displayColor ?? AppColors.categoryOther)
                                .withValues(alpha: 0.2),
                      ),
                      child: Icon(
                        category?.iconData ?? Icons.payments_rounded,
                        color:
                            category?.displayColor ?? AppColors.categoryOther,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.description?.trim().isNotEmpty == true
                                ? expense.description!
                                : categoryName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subcategoryName != null &&
                                    subcategoryName.isNotEmpty
                                ? '$categoryName • $subcategoryName'
                                : categoryName,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      amount,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 220.ms).slideX(begin: 0.06, end: 0),
            );
          }),
        ],
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({
    required this.icon,
    required this.label,
    required this.alignment,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(28),
      child: Column(
        children: const [
          Icon(
            Icons.wallet_giftcard_rounded,
            color: AppColors.textMuted,
            size: 52,
          ),
          SizedBox(height: 12),
          Text(
            'Your wallet is lonely',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Tap the mic to add your first expense.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.1, end: 0);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        GlassCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 50,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ],
    );
  }
}
