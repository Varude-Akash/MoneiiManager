import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/budgets/domain/entities/budget.dart';
import 'package:moneii_manager/features/budgets/presentation/providers/budget_provider.dart';

class SetBudgetSheet extends ConsumerStatefulWidget {
  const SetBudgetSheet({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.existingBudget,
  });

  final int categoryId;
  final String categoryName;
  final Budget? existingBudget;

  static Future<void> show(
    BuildContext context, {
    required int categoryId,
    required String categoryName,
    Budget? existingBudget,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SetBudgetSheet(
        categoryId: categoryId,
        categoryName: categoryName,
        existingBudget: existingBudget,
      ),
    );
  }

  @override
  ConsumerState<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends ConsumerState<SetBudgetSheet> {
  late final TextEditingController _amountController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.existingBudget != null
          ? widget.existingBudget!.amount.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String get _currency {
    final profile = ref.read(profileProvider).valueOrNull;
    return profile?.currencyPreference ?? 'USD';
  }

  Future<void> _save() async {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');

      final budget = Budget(
        id: widget.existingBudget?.id ?? '',
        userId: user.id,
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
        amount: amount,
        currency: _currency,
        isActive: true,
        createdAt: widget.existingBudget?.createdAt ?? DateTime.now(),
      );

      await ref.read(budgetActionsProvider.notifier).upsert(budget);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.existingBudget == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Budget?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Remove the budget for ${widget.categoryName}?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(budgetActionsProvider.notifier)
          .delete(widget.existingBudget!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currency = _currency;
    final symbol = NumberFormat.currency(name: currency).currencySymbol;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.glassBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            widget.existingBudget != null
                ? 'Edit Budget — ${widget.categoryName}'
                : 'Set Budget — ${widget.categoryName}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Set a monthly spending limit for this category.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Amount field
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
            decoration: InputDecoration(
              labelText: 'Monthly Budget Amount',
              prefixText: '$symbol ',
              prefixStyle: const TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              suffixText: currency,
              suffixStyle: const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.glassBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 24),

          // Save button
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.existingBudget != null ? 'Update Budget' : 'Set Budget',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),

          // Delete button
          if (widget.existingBudget != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isSaving ? null : _delete,
              child: const Text(
                'Delete Budget',
                style: TextStyle(color: AppColors.error, fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
