import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/constants.dart';
import 'package:moneii_manager/core/utils/date_utils.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/expenses/domain/entities/category.dart';
import 'package:moneii_manager/features/expenses/domain/entities/expense.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/category_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/expense_provider.dart';
import 'package:moneii_manager/features/voice/domain/entities/parsed_expense.dart';
import 'package:moneii_manager/features/voice/presentation/screens/voice_input_sheet.dart';

class AddExpenseInitialData {
  const AddExpenseInitialData({
    required this.amount,
    required this.categoryName,
    this.subcategoryName,
    required this.description,
    this.rawTranscript,
  });

  final double amount;
  final String categoryName;
  final String? subcategoryName;
  final String description;
  final String? rawTranscript;

  factory AddExpenseInitialData.fromParsed(ParsedExpense parsedExpense) {
    return AddExpenseInitialData(
      amount: parsedExpense.amount,
      categoryName: parsedExpense.categoryName,
      subcategoryName: parsedExpense.subcategoryName,
      description: parsedExpense.description,
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
      _rawTranscript = initialExpense.rawTranscript;
      return;
    }

    if (initialData != null) {
      if (initialData.amount > 0) {
        _amountController.text = initialData.amount.toStringAsFixed(2);
      }
      _descriptionController.text = initialData.description;
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

    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }
    if (_selectedCategoryId == null) {
      _showError('Choose a category');
      return;
    }

    HapticFeedback.mediumImpact();
    final existingCount = ref.read(expensesProvider).valueOrNull?.length ?? 0;
    final existing = widget.initialExpense;
    final expense = Expense(
      id: existing?.id ?? const Uuid().v4(),
      userId: user.id,
      amount: amount,
      currency: AppConstants.defaultCurrency,
      categoryId: _selectedCategoryId!,
      subcategoryId: _selectedSubcategoryId,
      categoryName: '',
      subcategoryName: null,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      expenseDate: _selectedDate,
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryTree = ref.watch(categoryTreeProvider);
    final addState = ref.watch(addExpenseProvider);
    final updateState = ref.watch(updateExpenseProvider);
    final isSaving = addState.isLoading || updateState.isLoading;

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
        title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
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
          _AmountCard(controller: _amountController),
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
              label: Text(_isEditing ? 'Update Expense' : 'Save Expense'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ).animate().fadeIn(duration: 250.ms),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.controller});

  final TextEditingController controller;

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
          const Text(
            '\$',
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
