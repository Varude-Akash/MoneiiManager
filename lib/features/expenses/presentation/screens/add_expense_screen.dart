import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/constants.dart';
import 'package:moneii_manager/core/premium/premium_features.dart';
import 'package:moneii_manager/core/utils/currency_utils.dart';
import 'package:moneii_manager/core/utils/date_utils.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/expenses/domain/entities/category.dart';
import 'package:moneii_manager/features/expenses/domain/entities/expense.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/category_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/expense_provider.dart';
import 'package:moneii_manager/features/profile/domain/entities/financial_account.dart';
import 'package:moneii_manager/features/profile/presentation/providers/financial_account_provider.dart';
import 'package:moneii_manager/features/voice/domain/entities/parsed_expense.dart';
import 'package:moneii_manager/features/voice/presentation/screens/voice_input_sheet.dart';
import 'package:moneii_manager/shared/widgets/premium_gate.dart';

class AddExpenseInitialData {
  const AddExpenseInitialData({
    required this.amount,
    required this.categoryName,
    this.subcategoryName,
    required this.description,
    required this.expenseDate,
    this.transactionType = 'expense',
    this.paymentSource = 'cash',
    this.accountNameHint,
    this.rawTranscript,
  });

  final double amount;
  final String categoryName;
  final String? subcategoryName;
  final String description;
  final DateTime expenseDate;
  final String transactionType;
  final String paymentSource;
  final String? accountNameHint;
  final String? rawTranscript;

  factory AddExpenseInitialData.fromParsed(ParsedExpense parsedExpense) {
    return AddExpenseInitialData(
      amount: parsedExpense.amount,
      categoryName: parsedExpense.categoryName,
      subcategoryName: parsedExpense.subcategoryName,
      description: parsedExpense.description,
      expenseDate: parsedExpense.expenseDate,
      transactionType: parsedExpense.transactionType,
      paymentSource: parsedExpense.paymentSource,
      accountNameHint: parsedExpense.accountNameHint,
      rawTranscript: parsedExpense.rawTranscript,
    );
  }
}

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, this.initialExpense, this.initialData});

  final Expense? initialExpense;
  final AddExpenseInitialData? initialData;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _confettiController = ConfettiController(
    duration: const Duration(milliseconds: 900),
  );
  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;
  int? _selectedSubcategoryId;
  String _transactionType = 'expense';
  String _paymentSource = 'cash';
  String? _selectedAccountId;
  String? _selectedDestinationAccountId;
  String? _accountNameHint;
  String? _rawTranscript;

  bool get _isEditing => widget.initialExpense != null;

  @override
  void initState() {
    super.initState();
    final initialExpense = widget.initialExpense;
    final initialData = widget.initialData;

    if (initialExpense != null) {
      _amountController.text = initialExpense.amount.toStringAsFixed(2);
      _descriptionController.text = initialExpense.description ?? '';
      _selectedDate = initialExpense.expenseDate;
      _selectedCategoryId = initialExpense.categoryId;
      _selectedSubcategoryId = initialExpense.subcategoryId;
      _transactionType = initialExpense.transactionType;
      _paymentSource = initialExpense.paymentSource;
      _selectedAccountId = initialExpense.accountId;
      _selectedDestinationAccountId = initialExpense.destinationAccountId;
      _rawTranscript = initialExpense.rawTranscript;
      return;
    }

    if (initialData != null) {
      if (initialData.amount > 0) {
        _amountController.text = initialData.amount.toStringAsFixed(2);
      }
      _descriptionController.text = initialData.description;
      _selectedDate = initialData.expenseDate;
      _transactionType = initialData.transactionType;
      _paymentSource = initialData.paymentSource;
      _accountNameHint = initialData.accountNameHint;
      _rawTranscript = initialData.rawTranscript;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _openVoiceInput() async {
    final parsedExpense = await showVoiceInputSheet(context);
    if (!mounted || parsedExpense == null) return;

    setState(() {
      _amountController.text = parsedExpense.amount > 0
          ? parsedExpense.amount.toStringAsFixed(2)
          : _amountController.text;
      _descriptionController.text = parsedExpense.description;
      _selectedDate = parsedExpense.expenseDate;
      _transactionType = parsedExpense.transactionType;
      _paymentSource = parsedExpense.paymentSource;
      _selectedAccountId = null;
      _selectedDestinationAccountId = null;
      _accountNameHint = parsedExpense.accountNameHint;
      _rawTranscript = parsedExpense.rawTranscript;
    });

    _matchCategoryNames(
      categoryName: parsedExpense.categoryName,
      subcategoryName: parsedExpense.subcategoryName,
    );
  }

  void _matchCategoryNames({
    required String categoryName,
    String? subcategoryName,
  }) {
    final groups = ref.read(categoryTreeProvider);
    for (final group in groups) {
      if (group.parent.name.toLowerCase() == categoryName.toLowerCase()) {
        setState(() {
          _selectedCategoryId = group.parent.id;
          _selectedSubcategoryId = null;
        });

        if (subcategoryName != null) {
          for (final subcategory in group.children) {
            if (subcategory.name.toLowerCase() ==
                subcategoryName.toLowerCase()) {
              setState(() {
                _selectedSubcategoryId = subcategory.id;
              });
              return;
            }
          }
        }
        return;
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _save() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final selectedCurrency =
        widget.initialExpense?.currency ??
        ref.read(profileProvider).valueOrNull?.currencyPreference ??
        AppConstants.defaultCurrency;

    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }
    if (_selectedCategoryId == null) {
      _showError('Choose a category');
      return;
    }

    final accounts = ref.read(financialAccountsProvider).valueOrNull ?? const [];
    final requiredType = _requiredAccountTypeForCurrentSelection();

    if (requiredType != null) {
      final availableForType = accounts
          .where((account) => account.accountType == requiredType)
          .toList();
      if (availableForType.isEmpty) {
        _showError(
          switch (requiredType) {
            'credit_card' => 'Add at least one credit card in Profile first.',
            'wallet' => 'Add at least one wallet in Profile first.',
            _ => 'Add at least one bank account in Profile first.',
          },
        );
        return;
      }
      if (_selectedAccountId == null) {
        _showError(
          switch (requiredType) {
            'credit_card' => 'Select which credit card was used.',
            'wallet' => 'Select which wallet was used.',
            _ => 'Select which bank account was used.',
          },
        );
        return;
      }
    }
    final destinationType = _requiredDestinationAccountType();
    if (destinationType != null) {
      final destinationOptions = accounts
          .where((account) => account.accountType == destinationType)
          .toList();
      if (destinationOptions.isEmpty) {
        _showError(
          destinationType == 'credit_card'
              ? 'Add at least one credit card in Profile first.'
              : 'Add at least one bank account in Profile first.',
        );
        return;
      }
      if (_selectedDestinationAccountId == null) {
        _showError(
          destinationType == 'credit_card'
              ? 'Select which credit card is being paid.'
              : 'Select destination account.',
        );
        return;
      }
      if (_selectedDestinationAccountId == _selectedAccountId) {
        _showError('From and To accounts cannot be the same.');
        return;
      }
    }

    HapticFeedback.mediumImpact();
    final existingCount = ref.read(expensesProvider).valueOrNull?.length ?? 0;
    final existing = widget.initialExpense;
    final expense = Expense(
      id: existing?.id ?? const Uuid().v4(),
      userId: user.id,
      amount: amount,
      currency: selectedCurrency,
      categoryId: _selectedCategoryId!,
      subcategoryId: _selectedSubcategoryId,
      categoryName: '',
      subcategoryName: null,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      expenseDate: _selectedDate,
      transactionType: _transactionType,
      paymentSource: _paymentSource,
      accountId: _selectedAccountId,
      destinationAccountId: _selectedDestinationAccountId,
      inputMethod: _rawTranscript == null ? 'manual' : 'voice',
      rawTranscript: _rawTranscript,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    try {
      if (_isEditing) {
        await ref.read(updateExpenseProvider.notifier).updateExpense(expense);
      } else {
        await ref.read(addExpenseProvider.notifier).addExpense(expense);
      }

      if (!mounted) return;
      if (!_isEditing && existingCount == 0) {
        _confettiController.play();
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (dialogContext) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      emissionFrequency: 0.08,
                      numberOfParticles: 30,
                      gravity: 0.2,
                      maxBlastForce: 24,
                      minBlastForce: 10,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: const Text(
                      'First expense added. Nice start!',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            );
          },
        );
        if (!mounted) return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Expense updated' : 'Expense saved'),
        ),
      );
      context.pop();
    } catch (error) {
      _showError(error.toString());
    }
  }

  void _autoselectAccount(List<FinancialAccount> accounts) {
    if (_selectedAccountId != null) return;

    final requiredType = _requiredAccountTypeForCurrentSelection();
    if (requiredType == null) return;

    final candidates = accounts
        .where((account) => account.accountType == requiredType)
        .toList();
    if (candidates.isEmpty) return;

    final transcript = (_rawTranscript ?? '').toLowerCase();
    final hint = (_accountNameHint ?? '').toLowerCase();
    if (transcript.isNotEmpty || hint.isNotEmpty) {
      for (final account in candidates) {
        final name = account.name.toLowerCase();
        if (name.isNotEmpty &&
            (transcript.contains(name) || (hint.isNotEmpty && name.contains(hint)))) {
          _selectedAccountId = account.id;
          return;
        }
      }
    }

    if (candidates.length == 1) {
      _selectedAccountId = candidates.first.id;
      return;
    }

    for (final account in candidates) {
      if (account.isDefault) {
        _selectedAccountId = account.id;
        return;
      }
    }
  }

  void _autoselectDestinationAccount(List<FinancialAccount> accounts) {
    if (_selectedDestinationAccountId != null) return;
    final destinationType = _requiredDestinationAccountType();
    if (destinationType == null) return;

    final options = accounts
        .where((account) => account.accountType == destinationType)
        .toList();
    if (options.isEmpty) return;

    for (final account in options) {
      if (account.isDefault && account.id != _selectedAccountId) {
        _selectedDestinationAccountId = account.id;
        return;
      }
    }
    for (final account in options) {
      if (account.id != _selectedAccountId) {
        _selectedDestinationAccountId = account.id;
        return;
      }
    }
  }

  String? _requiredAccountTypeForCurrentSelection() {
    if (_transactionType == 'credit_card_payment') return 'bank_account';
    if (_transactionType == 'transfer') return 'bank_account';
    if (_paymentSource == 'credit_card') return 'credit_card';
    if (_paymentSource == 'wallet') return 'wallet';
    if (_paymentSource == 'bank_account' ||
        (_transactionType == 'transfer' && _paymentSource == 'cash')) {
      return 'bank_account';
    }
    return null;
  }

  String? _requiredDestinationAccountType() {
    if (_transactionType == 'transfer') return 'bank_account';
    if (_transactionType == 'credit_card_payment') return 'credit_card';
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  String _transactionTypeLabel(String value) {
    switch (value) {
      case 'income':
        return 'Income';
      case 'transfer':
        return 'Transfer';
      case 'credit_card_payment':
        return 'Credit Card Bill';
      case 'expense':
      default:
        return 'Expense';
    }
  }

  String _paymentSourceLabel(String value) {
    switch (value) {
      case 'bank_account':
        return 'Bank Account';
      case 'credit_card':
        return 'Credit Card';
      case 'wallet':
        return 'Wallet';
      case 'cash':
      default:
        return 'Cash';
    }
  }

  String _screenTitle() {
    final noun = switch (_transactionType) {
      'income' => 'Income',
      'transfer' => 'Transfer',
      'credit_card_payment' => 'Card Bill',
      _ => 'Expense',
    };
    return _isEditing ? 'Edit $noun' : 'Add $noun';
  }

  String _saveButtonLabel() {
    final verb = _isEditing ? 'Update' : 'Save';
    final noun = switch (_transactionType) {
      'income' => 'Income',
      'transfer' => 'Transfer',
      'credit_card_payment' => 'Card Bill',
      _ => 'Expense',
    };
    return '$verb $noun';
  }

  @override
  Widget build(BuildContext context) {
    final categoryTree = ref.watch(categoryTreeProvider);
    final accounts = ref.watch(financialAccountsProvider).valueOrNull ?? const [];
    final preferredCurrency =
        widget.initialExpense?.currency ??
        ref.watch(profileProvider).valueOrNull?.currencyPreference ??
        AppConstants.defaultCurrency;
    final isPremium = ref.watch(profileProvider).valueOrNull?.isPremium ?? false;
    final addState = ref.watch(addExpenseProvider);
    final updateState = ref.watch(updateExpenseProvider);
    final isSaving = addState.isLoading || updateState.isLoading;

    _autoselectAccount(accounts);
    _autoselectDestinationAccount(accounts);

    if (widget.initialData != null &&
        _selectedCategoryId == null &&
        categoryTree.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _matchCategoryNames(
          categoryName: widget.initialData!.categoryName,
          subcategoryName: widget.initialData!.subcategoryName,
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle()),
        actions: [
          IconButton(
            onPressed: _openVoiceInput,
            icon: const Icon(Icons.mic_rounded),
            tooltip: 'Voice input',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _AmountCard(
            controller: _amountController,
            currencySymbol: CurrencyUtils.symbolFor(preferredCurrency),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _descriptionController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Coffee, rent, groceries...',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 20),
          _DatePickerTile(date: _selectedDate, onTap: _pickDate),
          const SizedBox(height: 16),
          _MetaDropdownRow(
            title: 'Transaction type',
            value: _transactionType,
            values: AppConstants.transactionTypes,
            onChanged: (value) => setState(() {
              _transactionType = value;
              _selectedAccountId = null;
              _selectedDestinationAccountId = null;
            }),
            labelBuilder: _transactionTypeLabel,
            icon: Icons.swap_horiz_rounded,
          ),
          const SizedBox(height: 12),
          _MetaDropdownRow(
            title: 'Paid/Received via',
            value: _paymentSource,
            values: AppConstants.paymentSources,
            onChanged: (value) => setState(() {
              _paymentSource = value;
              _selectedAccountId = null;
              _selectedDestinationAccountId = null;
            }),
            labelBuilder: _paymentSourceLabel,
            icon: Icons.account_balance_wallet_rounded,
          ),
          if (_requiredAccountTypeForCurrentSelection() != null) ...[
            const SizedBox(height: 12),
            _AccountDropdown(
              requiredType: _requiredAccountTypeForCurrentSelection()!,
              selectedAccountId: _selectedAccountId,
              accounts: accounts,
              onChanged: (value) {
                setState(() {
                  _selectedAccountId = value;
                });
              },
            ),
          ],
          if (_requiredDestinationAccountType() != null) ...[
            const SizedBox(height: 12),
            _AccountDropdown(
              titleOverride: _transactionType == 'credit_card_payment'
                  ? 'To credit card'
                  : 'To account',
              requiredType: _requiredDestinationAccountType()!,
              selectedAccountId: _selectedDestinationAccountId,
              accounts: accounts,
              excludedAccountId: _selectedAccountId,
              onChanged: (value) {
                setState(() {
                  _selectedDestinationAccountId = value;
                });
              },
            ),
          ],
          const SizedBox(height: 12),
          _PremiumInlineRow(isPremium: isPremium),
          const SizedBox(height: 20),
          const Text(
            'Category',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _CategoryGrid(
            groups: categoryTree,
            selectedCategoryId: _selectedCategoryId,
            onCategoryTap: (group) {
              HapticFeedback.selectionClick();
              setState(() {
                if (_selectedCategoryId == group.parent.id) {
                  _selectedCategoryId = null;
                  _selectedSubcategoryId = null;
                } else {
                  _selectedCategoryId = group.parent.id;
                  _selectedSubcategoryId = null;
                }
              });
            },
          ),
          if (_selectedCategoryId != null && categoryTree.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SubcategoryChips(
              group: categoryTree.firstWhere(
                (group) => group.parent.id == _selectedCategoryId,
                orElse: () => categoryTree.first,
              ),
              selectedSubcategoryId: _selectedSubcategoryId,
              onTap: (subcategoryId) {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedSubcategoryId =
                      _selectedSubcategoryId == subcategoryId
                      ? null
                      : subcategoryId;
                });
              },
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : _save,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: Text(_saveButtonLabel()),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ).animate().fadeIn(duration: 250.ms),
    );
  }
}

class _PremiumInlineRow extends StatelessWidget {
  const _PremiumInlineRow({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    Widget chip({
      required String label,
      required PremiumFeatureKey feature,
    }) {
      return InkWell(
        onTap: () => showPremiumFeatureGate(
          context,
          feature: feature,
          isPremium: isPremium,
        ),
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 13, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(
          label: 'Split with friends',
          feature: PremiumFeatureKey.sharedExpenses,
        ),
        chip(
          label: 'Receipt scanner',
          feature: PremiumFeatureKey.receiptScanner,
        ),
        chip(
          label: 'AI cleaner',
          feature: PremiumFeatureKey.aiSpendingInsights,
        ),
      ],
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.controller, required this.currencySymbol});

  final TextEditingController controller;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Text(
            currencySymbol,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaDropdownRow extends StatelessWidget {
  const _MetaDropdownRow({
    required this.title,
    required this.value,
    required this.values,
    required this.onChanged,
    required this.labelBuilder,
    required this.icon,
  });

  final String title;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;
  final String Function(String) labelBuilder;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: title,
        prefixIcon: Icon(icon),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(labelBuilder(item)),
            ),
          )
          .toList(),
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
    this.titleOverride,
    required this.requiredType,
    required this.selectedAccountId,
    required this.accounts,
    this.excludedAccountId,
    required this.onChanged,
  });

  final String? titleOverride;
  final String requiredType;
  final String? selectedAccountId;
  final List<FinancialAccount> accounts;
  final String? excludedAccountId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = accounts
        .where(
          (account) =>
              account.accountType == requiredType &&
              (excludedAccountId == null || account.id != excludedAccountId),
        )
        .toList();
    final label = switch (requiredType) {
      'credit_card' => 'Credit card',
      'wallet' => 'Wallet',
      _ => 'Bank account',
    };

    return DropdownButtonFormField<String>(
      initialValue: selectedAccountId,
      decoration: InputDecoration(
        labelText: titleOverride ??
            (options.isEmpty ? '$label (add in Profile first)' : label),
        prefixIcon: Icon(
          switch (requiredType) {
            'credit_card' => Icons.credit_card_rounded,
            'wallet' => Icons.account_balance_wallet_rounded,
            _ => Icons.account_balance_rounded,
          },
        ),
      ),
      items: options
          .map(
            (account) => DropdownMenuItem<String>(
              value: account.id,
              child: Text(
                account.isDefault ? '${account.name} (Default)' : account.name,
              ),
            ),
          )
          .toList(),
      onChanged: options.isEmpty ? null : onChanged,
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Text(
              AppDateUtils.formatDate(date),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.groups,
    required this.selectedCategoryId,
    required this.onCategoryTap,
  });

  final List<CategoryGroup> groups;
  final int? selectedCategoryId;
  final ValueChanged<CategoryGroup> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No categories found',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: groups.map((group) {
        final isSelected = selectedCategoryId == group.parent.id;

        return GestureDetector(
          onTap: () => onCategoryTap(group),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (MediaQuery.sizeOf(context).width - 60) / 2,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? group.parent.displayColor.withValues(alpha: 0.25)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? group.parent.displayColor
                    : AppColors.glassBorder,
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: group.parent.displayColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    group.parent.iconData,
                    size: 18,
                    color: group.parent.displayColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group.parent.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SubcategoryChips extends StatelessWidget {
  const _SubcategoryChips({
    required this.group,
    required this.selectedSubcategoryId,
    required this.onTap,
  });

  final CategoryGroup group;
  final int? selectedSubcategoryId;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (group.children.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: group.children.map((subcategory) {
        final isSelected = selectedSubcategoryId == subcategory.id;

        return ChoiceChip(
          label: Text(subcategory.name),
          selected: isSelected,
          onSelected: (_) => onTap(subcategory.id),
          selectedColor: AppColors.primary.withValues(alpha: 0.3),
          labelStyle: TextStyle(
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 12,
          ),
        );
      }).toList(),
    );
  }
}
