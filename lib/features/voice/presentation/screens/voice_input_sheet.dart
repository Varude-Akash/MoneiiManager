import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/premium/premium_features.dart';
import 'package:moneii_manager/core/utils/currency_utils.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/voice/domain/entities/parsed_expense.dart';
import 'package:moneii_manager/features/voice/presentation/providers/voice_input_provider.dart';
import 'package:moneii_manager/shared/widgets/premium_gate.dart';

Future<ParsedExpense?> showVoiceInputSheet(
  BuildContext context, {
  ParsedExpense? initialExpense,
}) {
  return showModalBottomSheet<ParsedExpense>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VoiceInputSheet(initialExpense: initialExpense),
  );
}

class _VoiceInputSheet extends ConsumerStatefulWidget {
  const _VoiceInputSheet({this.initialExpense});

  final ParsedExpense? initialExpense;

  @override
  ConsumerState<_VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends ConsumerState<_VoiceInputSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  ParsedExpense? _editableExpense;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialExpense;
    if (initial != null) {
      _editableExpense = initial;
      _amountController.text = initial.amount.toStringAsFixed(2);
      _descriptionController.text = initial.description;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceInputProvider);
    final notifier = ref.read(voiceInputProvider.notifier);
    final preferredCurrency =
        ref.watch(profileProvider).valueOrNull?.currencyPreference ?? 'USD';
    final isPremium = ref.watch(profileProvider).valueOrNull?.isPremium ?? false;
    final currencySymbol = CurrencyUtils.symbolFor(preferredCurrency);

    if (state is VoiceParsed && _editableExpense == null) {
      _editableExpense = state.expense;
      _amountController.text = state.expense.amount.toStringAsFixed(2);
      _descriptionController.text = state.expense.description;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppColors.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Voice Input',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if ((state is VoiceIdle || state is VoiceRecording) &&
                      _editableExpense == null)
                    _buildMicSection(state, notifier),
                  if (state is VoiceTranscribing && _editableExpense == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                          SizedBox(height: 20),
                          _ThinkingText(),
                        ],
                      ),
                    ),
                  if (_editableExpense != null)
                    _buildParsedSection(
                      context,
                      _editableExpense!,
                      notifier,
                      currencySymbol,
                      isPremium,
                    ),
                  if (state is VoiceError)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            state.message,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: notifier.reset,
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Try again'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    final route = GoRouterState.of(
                                      context,
                                    ).matchedLocation;
                                    Navigator.pop(context);
                                    if (route != '/add-expense') {
                                      context.push('/add-expense');
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.edit_note_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Add manually'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicSection(VoiceInputState state, VoiceInputNotifier notifier) {
    final isRecording = state is VoiceRecording;
    Widget mic = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isRecording ? AppColors.accent : AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: (isRecording ? AppColors.accent : AppColors.primary)
                .withValues(alpha: 0.45),
            blurRadius: isRecording ? 28 : 12,
            spreadRadius: isRecording ? 6 : 0,
          ),
        ],
      ),
      child: Icon(
        isRecording ? Icons.stop_rounded : Icons.mic_rounded,
        color: Colors.white,
        size: 44,
      ),
    );

    if (isRecording) {
      mic = mic
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.12, 1.12),
            duration: 700.ms,
          );
    }

    return Column(
      children: [
        Text(
          isRecording ? 'Listening...' : 'Tap to speak',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 20),
        if (isRecording) const _Waveform(),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => isRecording
              ? notifier.stopAndTranscribe()
              : notifier.startRecording(),
          child: mic,
        ),
        const SizedBox(height: 24),
        const Text(
          'Speak naturally, e.g. "Spent 12 dollars on lunch"',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildParsedSection(
    BuildContext context,
    ParsedExpense expense,
    VoiceInputNotifier notifier,
    String currencySymbol,
    bool isPremium,
  ) {
    final saveLabel = switch (expense.transactionType) {
      'income' => 'Save Income',
      'transfer' => 'Save Transfer',
      'credit_card_payment' => 'Save Card Bill',
      _ => 'Save Expense',
    };

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.glassWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.category_outlined,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      expense.subcategoryName != null
                          ? '${expense.categoryName} > ${expense.subcategoryName}'
                          : expense.categoryName,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(expense.confidence * 100).round()}%',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: currencySymbol,
                  prefixStyle: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => _onEdit(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (_) => _onEdit(),
              ),
              const SizedBox(height: 8),
              Text(
                '"${expense.rawTranscript}"',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => showPremiumFeatureGate(
                    context,
                    feature: PremiumFeatureKey.aiFinancialCoach,
                    isPremium: isPremium,
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('AI Voice Assistant (Premium)'),
                ),
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: 0.1),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  notifier.reset();
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: BorderSide(color: AppColors.glassBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  final amount =
                      double.tryParse(_amountController.text.trim()) ??
                      expense.amount;
                  final edited = expense.copyWith(
                    amount: amount,
                    description: _descriptionController.text.trim(),
                  );
                  Navigator.pop(context, edited);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(saveLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onEdit() {
    final current = _editableExpense;
    if (current == null) return;

    final amount =
        double.tryParse(_amountController.text.trim()) ?? current.amount;
    setState(() {
      _editableExpense = current.copyWith(
        amount: amount,
        description: _descriptionController.text.trim(),
      );
    });
  }
}

class _ThinkingText extends StatelessWidget {
  const _ThinkingText();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Thinking',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
        const SizedBox(width: 4),
        ...List.generate(3, (index) {
          return const Text(
                '.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .fadeIn(
                delay: Duration(milliseconds: index * 200),
                duration: 300.ms,
              )
              .fadeOut(delay: 300.ms, duration: 300.ms);
        }),
      ],
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(20, (index) {
          final targetHeight = 10.0 + (index % 5) * 6;
          return Container(
                width: 6,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(100),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .moveY(
                begin: 10,
                end: -targetHeight,
                duration: (350 + index * 20).ms,
                curve: Curves.easeInOut,
              );
        }),
      ),
    );
  }
}
