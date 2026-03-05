import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/goals/domain/entities/savings_goal.dart';
import 'package:moneii_manager/features/goals/presentation/providers/goals_provider.dart';

const _presetEmojis = ['🎯', '✈️', '🏠', '🚗', '💰', '📱', '🎓', '💍', '🏋️', '🌴'];

const _presetColors = [
  Color(0xFF7C3AED), // purple
  Color(0xFF06B6D4), // cyan
  Color(0xFF10B981), // green
  Color(0xFFF59E0B), // amber
  Color(0xFFEF4444), // red
  Color(0xFFEC4899), // pink
];

class AddGoalSheet extends ConsumerStatefulWidget {
  const AddGoalSheet({super.key, this.existingGoal});

  final SavingsGoal? existingGoal;

  static Future<void> show(
    BuildContext context, {
    SavingsGoal? existingGoal,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddGoalSheet(existingGoal: existingGoal),
    );
  }

  @override
  ConsumerState<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<AddGoalSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late String _selectedEmoji;
  late Color _selectedColor;
  DateTime? _deadline;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.existingGoal;
    _nameController = TextEditingController(text: g?.name ?? '');
    _targetController = TextEditingController(
      text: g != null ? g.targetAmount.toStringAsFixed(2) : '',
    );
    _selectedEmoji = g?.icon ?? '🎯';
    _selectedColor = g != null ? _parseColor(g.color) : _presetColors[0];
    _deadline = g?.deadline;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      final full = clean.length == 6 ? 'FF$clean' : clean;
      return Color(int.parse(full, radix: 16));
    } catch (_) {
      return _presetColors[0];
    }
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a goal name')),
      );
      return;
    }
    final target = double.tryParse(_targetController.text.trim());
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid target amount')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) throw Exception('Not authenticated');

      final profile = ref.read(profileProvider).valueOrNull;
      final currency = profile?.currencyPreference ?? 'USD';

      if (widget.existingGoal != null) {
        final updated = widget.existingGoal!.copyWith(
          name: name,
          targetAmount: target,
          deadline: _deadline,
          clearDeadline: _deadline == null,
          icon: _selectedEmoji,
          color: _colorToHex(_selectedColor),
          currency: currency,
        );
        await ref.read(goalActionsProvider.notifier).updateGoal(updated);
      } else {
        final goal = SavingsGoal(
          id: '',
          userId: user.id,
          name: name,
          targetAmount: target,
          currentAmount: 0,
          deadline: _deadline,
          icon: _selectedEmoji,
          color: _colorToHex(_selectedColor),
          currency: currency,
          isCompleted: false,
          createdAt: DateTime.now(),
        );
        await ref.read(goalActionsProvider.notifier).addGoal(goal);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.existingGoal == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Goal?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete "${widget.existingGoal!.name}"?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(goalActionsProvider.notifier)
          .deleteGoal(widget.existingGoal!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existingGoal != null;

    return SingleChildScrollView(
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

          Text(
            isEditing ? 'Edit Goal' : 'New Savings Goal',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // Name field
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration('Goal name (e.g. Vacation Fund)'),
            autofocus: !isEditing,
          ),
          const SizedBox(height: 14),

          // Target amount
          TextField(
            controller: _targetController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration('Target amount'),
          ),
          const SizedBox(height: 20),

          // Emoji picker
          const Text(
            'Icon',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetEmojis.map((emoji) {
              final selected = emoji == _selectedEmoji;
              return GestureDetector(
                onTap: () => setState(() => _selectedEmoji = emoji),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected
                        ? _selectedColor.withValues(alpha: 0.2)
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? _selectedColor : AppColors.glassBorder,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Color picker
          const Text(
            'Color',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: _presetColors.map((color) {
              final selected = color.toARGB32() == _selectedColor.toARGB32();
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          selected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Deadline picker
          InkWell(
            onTap: _pickDeadline,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _deadline != null
                          ? 'Deadline: ${_deadline!.day}/${_deadline!.month}/${_deadline!.year}'
                          : 'Set deadline (optional)',
                      style: TextStyle(
                        color: _deadline != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (_deadline != null)
                    GestureDetector(
                      onTap: () => setState(() => _deadline = null),
                      child: const Icon(Icons.close,
                          color: AppColors.textMuted, size: 16),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    isEditing ? 'Update Goal' : 'Create Goal',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),

          if (isEditing) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isSaving ? null : _delete,
              child: const Text('Delete Goal',
                  style: TextStyle(color: AppColors.error, fontSize: 14)),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
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
    );
  }
}
