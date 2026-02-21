import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/premium/premium_features.dart';
import 'package:moneii_manager/core/providers/exchange_rate_provider.dart';
import 'package:moneii_manager/core/utils/currency_utils.dart';
import 'package:moneii_manager/core/utils/date_utils.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/expenses/domain/entities/category.dart';
import 'package:moneii_manager/features/expenses/domain/entities/expense.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/category_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/expense_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:moneii_manager/features/profile/domain/entities/financial_account.dart';
import 'package:moneii_manager/features/profile/presentation/providers/financial_account_provider.dart';
import 'package:moneii_manager/features/voice/presentation/screens/voice_input_sheet.dart';
import 'package:moneii_manager/shared/widgets/premium_gate.dart';
import 'package:moneii_manager/shared/widgets/glass_card.dart';
import 'package:moneii_manager/shared/widgets/shimmer_skeleton.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final accounts = ref.watch(financialAccountsProvider).valueOrNull ?? const [];
    final preferredCurrency = profile?.currencyPreference ?? 'USD';
    final usdRates = ref.watch(supportedExchangeRatesProvider);
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
              final visibleExpenses = expenses.where((expense) {
                return expense.expenseDate.year == _selectedMonth.year &&
                    expense.expenseDate.month == _selectedMonth.month;
              }).toList();

              if (expenses.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _Header(
                      accounts: accounts,
                      profileName: profile?.displayName,
                      isPremium: profile?.isPremium ?? false,
                      selectedMonth: _selectedMonth,
                      preferredCurrency: preferredCurrency,
                    ),
                    const SizedBox(height: 12),
                    _TransactionMonthSelector(
                      selectedMonth: _selectedMonth,
                      earliestMonth: _earliestMonth(expenses),
                      onChanged: (month) {
                        setState(() => _selectedMonth = month);
                      },
                    ),
                    const SizedBox(height: 72),
                    const _EmptyState(),
                  ],
                );
              }

              final grouped = _groupExpensesByDate(visibleExpenses);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                children: [
                  _Header(
                    accounts: accounts,
                    profileName: profile?.displayName,
                    isPremium: profile?.isPremium ?? false,
                    selectedMonth: _selectedMonth,
                    preferredCurrency: preferredCurrency,
                  ),
                  const SizedBox(height: 12),
                  _TransactionMonthSelector(
                    selectedMonth: _selectedMonth,
                    earliestMonth: _earliestMonth(expenses),
                    onChanged: (month) {
                      setState(() => _selectedMonth = month);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (grouped.isEmpty)
                    const _EmptyState()
                  else
                    ...grouped.entries.map((entry) {
                      return _ExpenseGroup(
                        date: entry.key,
                        expenses: entry.value,
                        categoryById: categoryById,
                        preferredCurrency: preferredCurrency,
                        usdRates: usdRates,
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

  DateTime _earliestMonth(List<Expense> expenses) {
    if (expenses.isEmpty) {
      final now = DateTime.now();
      return DateTime(now.year, now.month);
    }
    var earliest = expenses.first.expenseDate;
    for (final expense in expenses) {
      if (expense.expenseDate.isBefore(earliest)) earliest = expense.expenseDate;
    }
    return DateTime(earliest.year, earliest.month);
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

class _TransactionMonthSelector extends StatefulWidget {
  const _TransactionMonthSelector({
    required this.selectedMonth,
    required this.earliestMonth,
    required this.onChanged,
  });

  final DateTime selectedMonth;
  final DateTime earliestMonth;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_TransactionMonthSelector> createState() =>
      _TransactionMonthSelectorState();
}

class _TransactionMonthSelectorState extends State<_TransactionMonthSelector> {
  late final ScrollController _controller;
  var _canScrollLeft = false;
  var _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_syncIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndicators());
  }

  @override
  void dispose() {
    _controller.removeListener(_syncIndicators);
    _controller.dispose();
    super.dispose();
  }

  void _syncIndicators() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final offset = _controller.offset;
    final nextLeft = offset > 4;
    final nextRight = offset < max - 4;
    if (nextLeft != _canScrollLeft || nextRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = nextLeft;
        _canScrollRight = nextRight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthCount =
        ((now.year - widget.earliestMonth.year) * 12) +
        (now.month - widget.earliestMonth.month) +
        1;
    final safeCount = monthCount.clamp(1, 600);
    final months = List.generate(
      safeCount,
      (index) => DateTime(now.year, now.month - index),
    );

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  itemCount: months.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final month = months[index];
                    final selected =
                        month.year == widget.selectedMonth.year &&
                        month.month == widget.selectedMonth.month;
                    return ChoiceChip(
                      label: Text(
                        AppDateUtils.formatMonth(month),
                        style: const TextStyle(fontSize: 11),
                      ),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      selected: selected,
                      onSelected: (_) =>
                          widget.onChanged(DateTime(month.year, month.month)),
                    );
                  },
                ),
                if (_canScrollLeft)
                  const Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: _HorizontalEdgeIndicator(
                      alignment: Alignment.centerLeft,
                      icon: Icons.chevron_left_rounded,
                    ),
                  ),
                if (_canScrollRight)
                  const Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: _HorizontalEdgeIndicator(
                      alignment: Alignment.centerRight,
                      icon: Icons.chevron_right_rounded,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Jump to month',
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.selectedMonth,
                firstDate: widget.earliestMonth,
                lastDate: DateTime(now.year, now.month, now.day),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.primary,
                        surface: AppColors.surface,
                      ),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
              if (picked != null) {
                widget.onChanged(DateTime(picked.year, picked.month));
              }
            },
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.accounts,
    required this.profileName,
    required this.isPremium,
    required this.selectedMonth,
    required this.preferredCurrency,
  });

  final List<FinancialAccount> accounts;
  final String? profileName;
  final bool isPremium;
  final DateTime selectedMonth;
  final String preferredCurrency;

  @override
  Widget build(BuildContext context) {
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
          AppDateUtils.formatMonth(selectedMonth),
          style: const TextStyle(color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 10),
        if (accounts.isEmpty) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => context.push('/profile?openAddAccount=1'),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_card_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add your first account',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Track balances, transfers, and card usage better.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 170.ms).slideY(begin: 0.06),
        ],
        if (accounts.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 66,
            child: _AccountBalanceScroller(
              accounts: accounts,
              preferredCurrency: preferredCurrency,
            ),
          ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.1),
        ],
        const SizedBox(height: 12),
        _PremiumHomeRow(isPremium: isPremium),
      ],
    );
  }
}

class _AccountBalanceScroller extends ConsumerStatefulWidget {
  const _AccountBalanceScroller({
    required this.accounts,
    required this.preferredCurrency,
  });

  final List<FinancialAccount> accounts;
  final String preferredCurrency;

  @override
  ConsumerState<_AccountBalanceScroller> createState() =>
      _AccountBalanceScrollerState();
}

class _AccountBalanceScrollerState extends ConsumerState<_AccountBalanceScroller> {
  late final ScrollController _controller;
  var _canScrollLeft = false;
  var _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_syncIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndicators());
  }

  @override
  void dispose() {
    _controller.removeListener(_syncIndicators);
    _controller.dispose();
    super.dispose();
  }

  void _syncIndicators() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    final offset = _controller.offset;
    final nextLeft = offset > 4;
    final nextRight = offset < max - 4;
    if (nextLeft != _canScrollLeft || nextRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = nextLeft;
        _canScrollRight = nextRight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.separated(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          itemCount: widget.accounts.length,
          separatorBuilder: (context, index) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final account = widget.accounts[index];
            final icon = switch (account.accountType) {
              'credit_card' => Icons.credit_card_rounded,
              'wallet' => Icons.account_balance_wallet_rounded,
              _ => Icons.account_balance_rounded,
            };
            final balanceColor = account.currentBalance < 0
                ? AppColors.error
                : AppColors.textPrimary;
            final valueText = account.accountType == 'credit_card'
                ? 'Avail ${CurrencyUtils.format(account.currentBalance, currency: widget.preferredCurrency)}'
                : CurrencyUtils.format(
                    account.currentBalance,
                    currency: widget.preferredCurrency,
                  );
            final secondaryText = account.accountType == 'credit_card'
                ? 'Used ${CurrencyUtils.format(account.utilizedAmount, currency: widget.preferredCurrency)} / ${CurrencyUtils.format(account.creditLimit, currency: widget.preferredCurrency)}'
                : null;
            return Container(
              width: 220,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          valueText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: balanceColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (secondaryText != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            secondaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showQuickEditDialog(account),
                    tooltip: 'Quick edit',
                    icon: const Icon(Icons.edit_rounded, size: 17),
                    color: AppColors.textMuted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 22,
                      minHeight: 22,
                    ),
                    visualDensity: const VisualDensity(
                      horizontal: -3,
                      vertical: -3,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (_canScrollLeft)
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _HorizontalEdgeIndicator(
              alignment: Alignment.centerLeft,
              icon: Icons.chevron_left_rounded,
            ),
          ),
        if (_canScrollRight)
          const Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _HorizontalEdgeIndicator(
              alignment: Alignment.centerRight,
              icon: Icons.chevron_right_rounded,
            ),
          ),
      ],
    );
  }

  Future<void> _showQuickEditDialog(FinancialAccount account) async {
    final messenger = ScaffoldMessenger.of(context);
    final primaryController = TextEditingController(
      text: account.accountType == 'credit_card'
          ? account.creditLimit.toStringAsFixed(2)
          : account.initialBalance.toStringAsFixed(2),
    );
    final utilizedController = TextEditingController(
      text: account.utilizedAmount.toStringAsFixed(2),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Edit ${account.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: primaryController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: account.accountType == 'credit_card'
                      ? 'Credit limit'
                      : 'Account balance',
                ),
              ),
              if (account.accountType == 'credit_card') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: utilizedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Utilized amount',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true) return;
    final primary =
        double.tryParse(primaryController.text.trim().replaceAll(',', '')) ?? 0;
    final utilized =
        double.tryParse(utilizedController.text.trim().replaceAll(',', '')) ?? 0;

    if (account.accountType == 'credit_card' && primary <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid credit limit.')),
      );
      return;
    }
    if (account.accountType == 'credit_card' && utilized < 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Utilized amount cannot be negative.')),
      );
      return;
    }

    try {
      await ref
          .read(financialAccountActionsProvider.notifier)
          .updateAccount(
            account: account,
            name: account.name,
            isDefault: account.isDefault,
            initialBalance: account.accountType == 'credit_card' ? null : primary,
            creditLimit: account.accountType == 'credit_card' ? primary : null,
            utilizedAmount: account.accountType == 'credit_card' ? utilized : null,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Account updated.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class _HorizontalEdgeIndicator extends StatelessWidget {
  const _HorizontalEdgeIndicator({
    required this.alignment,
    required this.icon,
  });

  final Alignment alignment;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 28,
        alignment: alignment,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: alignment == Alignment.centerLeft
                ? Alignment.centerLeft
                : Alignment.centerRight,
            end: alignment == Alignment.centerLeft
                ? Alignment.centerRight
                : Alignment.centerLeft,
            colors: [
              AppColors.background.withValues(alpha: 0.95),
              AppColors.background.withValues(alpha: 0),
            ],
          ),
        ),
        child: Icon(icon, size: 18, color: AppColors.textMuted),
      ),
    );
  }
}

class _PremiumHomeRow extends StatelessWidget {
  const _PremiumHomeRow({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    Widget card({
      required String title,
      required String subtitle,
      required PremiumFeatureKey key,
      required IconData icon,
    }) {
      return Expanded(
        child: InkWell(
          onTap: () => showPremiumFeatureGate(
            context,
            feature: key,
            isPremium: isPremium,
          ),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppColors.primary, size: 16),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card(
          title: 'AI Insights',
          subtitle: 'Understand hidden spend patterns',
          key: PremiumFeatureKey.aiSpendingInsights,
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(width: 10),
        card(
          title: 'Spend Forecast',
          subtitle: 'Predict next month outflow',
          key: PremiumFeatureKey.expensePredictions,
          icon: Icons.trending_up_rounded,
        ),
      ],
    );
  }
}

class _ExpenseGroup extends ConsumerWidget {
  const _ExpenseGroup({
    required this.date,
    required this.expenses,
    required this.categoryById,
    required this.preferredCurrency,
    required this.usdRates,
  });

  final DateTime date;
  final List<Expense> expenses;
  final Map<int, ExpenseCategory> categoryById;
  final String preferredCurrency;
  final Map<String, double> usdRates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: Text(
              AppDateUtils.formatGroupHeader(date),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
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
            final convertedAmount = CurrencyUtils.convert(
              expense.amount,
              fromCurrency: expense.currency,
              toCurrency: preferredCurrency,
              usdRates: usdRates,
            );
            final signedAmount = expense.transactionType == 'income'
                ? convertedAmount
                : -convertedAmount;
            final amountPrefix = signedAmount >= 0 ? '+' : '-';
            final amount = '$amountPrefix${CurrencyUtils.format(signedAmount.abs(), currency: preferredCurrency)}';
            final typeLabel = _transactionTypeLabel(expense.transactionType);

            return Slidable(
              key: ValueKey(expense.id),
              endActionPane: ActionPane(
                motion: const StretchMotion(),
                extentRatio: 0.46,
                children: [
                  SlidableAction(
                    onPressed: (_) => context.push('/add-expense', extra: expense),
                    backgroundColor: AppColors.accent.withValues(alpha: 0.25),
                    foregroundColor: AppColors.accent,
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    borderRadius: BorderRadius.circular(16),
                  ),
                  SlidableAction(
                    onPressed: (_) async {
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
                    backgroundColor: AppColors.error.withValues(alpha: 0.25),
                    foregroundColor: AppColors.error,
                    icon: Icons.delete_rounded,
                    label: 'Delete',
                    borderRadius: BorderRadius.circular(16),
                  ),
                ],
              ),
              child: GlassCard(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
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
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            expense.description?.trim().isNotEmpty == true
                                ? expense.description!
                                : categoryName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subcategoryName != null &&
                                    subcategoryName.isNotEmpty
                                ? '$categoryName • $subcategoryName'
                                : '$categoryName • $typeLabel',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amount,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
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

String _transactionTypeLabel(String value) {
  switch (value) {
    case 'income':
      return 'Income';
    case 'transfer':
      return 'Transfer';
    case 'credit_card_payment':
      return 'Card Bill';
    case 'expense':
    default:
      return 'Expense';
  }
}
