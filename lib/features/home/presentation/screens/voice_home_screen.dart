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
  Future<void> _onMicTap(VoiceInputState state) async {
    final notifier = ref.read(voiceInputProvider.notifier);
    HapticFeedback.mediumImpact();
    if (state is VoiceRecording) {
      await notifier.stopAndTranscribe();
      final resultState = ref.read(voiceInputProvider);
      if (!mounted) return;
      if (resultState is VoiceParsed) {
        final parsed = await showVoiceInputSheet(
          context,
          initialExpense: resultState.expense,
        );
        if (parsed != null && mounted) {
          await context.push(
            '/add-expense',
            extra: AddExpenseInitialData.fromParsed(parsed),
          );
        }
        if (mounted) {
          ref.read(voiceInputProvider.notifier).reset();
        }
      }
      return;
    }
    if (state is VoiceTranscribing) return;
    notifier.reset();
    await notifier.startRecording();
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider).valueOrNull ?? const [];
    final voiceState = ref.watch(voiceInputProvider);
    final isRecording = voiceState is VoiceRecording;
    final isTranscribing = voiceState is VoiceTranscribing;
    final compactScreen = MediaQuery.sizeOf(context).height < 760;
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
            child: Column(
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
                Expanded(
                  child: Center(
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
                                : 'Tap and speak naturally',
                            style: const TextStyle(color: AppColors.textPrimary),
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
                          const SizedBox(height: 10),
                          const Text(
                            'Expense • Income • Transfer • Card bill',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
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
                          const SizedBox(height: 18),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 42,
                                    child: OutlinedButton.icon(
                                      onPressed: () => context.push('/add-expense'),
                                      icon: const Icon(
                                        Icons.edit_note_rounded,
                                        size: 18,
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
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SizedBox(
                                    height: 42,
                                    child: OutlinedButton.icon(
                                      onPressed: voiceState is VoiceError
                                          ? () async => _onMicTap(const VoiceIdle())
                                          : () => context.go('/activity'),
                                      icon: Icon(
                                        voiceState is VoiceError
                                            ? Icons.refresh_rounded
                                            : Icons.list_alt_rounded,
                                        size: 18,
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
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08),
                    ),
                  ),
                ),
              ],
            ),
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
