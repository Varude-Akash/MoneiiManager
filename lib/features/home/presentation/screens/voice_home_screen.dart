import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/utils/date_utils.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/expense_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:moneii_manager/features/voice/presentation/providers/voice_input_provider.dart';
import 'package:moneii_manager/features/voice/presentation/screens/voice_input_sheet.dart';

class VoiceHomeScreen extends ConsumerStatefulWidget {
  const VoiceHomeScreen({super.key});

  @override
  ConsumerState<VoiceHomeScreen> createState() => _VoiceHomeScreenState();
}

class _VoiceHomeScreenState extends ConsumerState<VoiceHomeScreen> {
  bool _isHandlingParsed = false;

  Future<void> _onMicTap(VoiceInputState state) async {
    final notifier = ref.read(voiceInputProvider.notifier);
    HapticFeedback.mediumImpact();
    if (state is VoiceRecording) {
      await notifier.stopAndTranscribe();
      return;
    }
    if (state is VoiceTranscribing) return;
    notifier.reset();
    await notifier.startRecording();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VoiceInputState>(voiceInputProvider, (previous, next) async {
      if (next is! VoiceParsed || _isHandlingParsed || !mounted) return;
      _isHandlingParsed = true;
      try {
        final parsed = await showVoiceInputSheet(
          context,
          initialExpense: next.expense,
        );
        if (parsed != null && context.mounted) {
          await context.push(
            '/add-expense',
            extra: AddExpenseInitialData.fromParsed(parsed),
          );
        }
      } finally {
        if (mounted) {
          ref.read(voiceInputProvider.notifier).reset();
        }
        _isHandlingParsed = false;
      }
    });

    final expenses = ref.watch(expensesProvider).valueOrNull ?? const [];
    final voiceState = ref.watch(voiceInputProvider);
    final isRecording = voiceState is VoiceRecording;
    final isTranscribing = voiceState is VoiceTranscribing;
    final compactScreen = MediaQuery.sizeOf(context).height < 760;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomContentPadding = 132.0 + bottomInset;
    final micSize = compactScreen ? 148.0 : 168.0;
    final micIconSize = compactScreen ? 60.0 : 68.0;
    final today = DateTime.now();
    final voiceToday = expenses.where((expense) {
      return expense.inputMethod == 'voice' &&
          expense.expenseDate.year == today.year &&
          expense.expenseDate.month == today.month &&
          expense.expenseDate.day == today.day;
    }).toList();
    Widget mic = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: micSize,
          height: micSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRecording
                ? AppColors.accent
                : isTranscribing
                ? AppColors.surfaceLight
                : AppColors.primary,
            boxShadow: [
              BoxShadow(
                color:
                    (isRecording
                            ? AppColors.accent
                            : isTranscribing
                            ? AppColors.surfaceLight
                            : AppColors.primary)
                        .withValues(alpha: 0.45),
                blurRadius: isRecording || isTranscribing ? 28 : 12,
                spreadRadius: isRecording || isTranscribing ? 6 : 0,
              ),
            ],
          ),
          child: Icon(
            isRecording
                ? Icons.stop_rounded
                : isTranscribing
                ? Icons.hourglass_top_rounded
                : Icons.mic_rounded,
            size: micIconSize,
            color: Colors.white,
          ),
        ),
        if (isTranscribing)
          SizedBox(
            width: micSize + 18,
            height: micSize + 18,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              backgroundColor: AppColors.glassBorder.withValues(alpha: 0.35),
            ),
          ),
      ],
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

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottomContentPadding),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Speak, and it is done.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate().fadeIn(duration: 260.ms).slideY(begin: -0.08),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppDateUtils.formatMonth(today),
                  style: const TextStyle(color: AppColors.textSecondary),
                ).animate().fadeIn(delay: 80.ms),
              ),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (voiceState is VoiceRecording) ...[
                          const _PopupLikeWaveform(),
                          const SizedBox(height: 12),
                        ],
                        GestureDetector(
                          onTap: () => _onMicTap(voiceState),
                          child: mic,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          isTranscribing
                              ? 'Processing your voice...'
                              : 'One tap, then speak your money move: spent, earned, transferred, or paid card bill.',
                          style: const TextStyle(color: AppColors.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (voiceState is VoiceTranscribing)
                          const _ThinkingDots()
                        else
                          Builder(
                            builder: (context) {
                              final message = switch (voiceState) {
                                VoiceRecording() =>
                                  'Listening... tap again to stop',
                                VoiceParsed() => 'Opening voice preview...',
                                VoiceError() => 'Could not parse clearly.',
                                _ => '',
                              };
                              if (message.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                message,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        if (voiceState is VoiceError) ...[
                          const SizedBox(height: 6),
                          Text(
                            voiceState.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '${voiceToday.length} voice entr${voiceToday.length == 1 ? 'y' : 'ies'} today',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: compactScreen ? 8 : 10),
                        const Text(
                          'Expense • Income • Transfer • Card bill',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (!compactScreen) ...[
                          const SizedBox(height: 6),
                          const Text(
                            'e.g. Spent 250 • Salary credited • Transferred 5000 • Paid card bill',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        SizedBox(height: compactScreen ? 12 : 18),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: OutlinedButton.icon(
                                    onPressed: () => context.push('/add-expense'),
                                    icon: const Icon(
                                      Icons.edit_note_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Add'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.textSecondary,
                                      side: BorderSide(
                                        color: AppColors.glassBorder.withValues(alpha: 0.75),
                                      ),
                                      backgroundColor: AppColors.surfaceLight.withValues(
                                        alpha: 0.35,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: OutlinedButton.icon(
                                    onPressed: voiceState is VoiceError
                                        ? () async => _onMicTap(const VoiceIdle())
                                        : () => context.go('/activity'),
                                    icon: Icon(
                                      voiceState is VoiceError
                                          ? Icons.refresh_rounded
                                          : Icons.list_alt_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      voiceState is VoiceError
                                          ? 'Try Again'
                                          : 'Activity',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.textSecondary,
                                      side: BorderSide(
                                        color: AppColors.glassBorder.withValues(alpha: 0.75),
                                      ),
                                      backgroundColor: AppColors.surfaceLight.withValues(
                                        alpha: 0.35,
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => context.push('/moneii-ai'),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight.withValues(alpha: 0.48),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Meet Moneii AI',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Chat with your own data. Ask what changed, where money leaked, and what to do next.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: const [
                                          _AssistantPromptPill(
                                            label: 'Where did I overspend?',
                                          ),
                                          _AssistantPromptPill(
                                            label: 'How much came in this month?',
                                          ),
                                          _AssistantPromptPill(
                                            label: 'Any savings suggestions?',
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupLikeWaveform extends StatelessWidget {
  const _PopupLikeWaveform();

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

class _AssistantPromptPill extends StatelessWidget {
  const _AssistantPromptPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ThinkingDots extends StatelessWidget {
  const _ThinkingDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Thinking',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(width: 4),
        ...List.generate(3, (index) {
          return const Text(
                '.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
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
