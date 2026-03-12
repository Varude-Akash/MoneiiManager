import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/premium/premium_features.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/moneii_ai/presentation/providers/moneii_ai_provider.dart';
import 'package:moneii_manager/features/subscriptions/presentation/providers/revenuecat_provider.dart';
import 'package:moneii_manager/shared/widgets/premium_gate.dart';

class MoneiiAiScreen extends ConsumerStatefulWidget {
  const MoneiiAiScreen({super.key});

  @override
  ConsumerState<MoneiiAiScreen> createState() => _MoneiiAiScreenState();
}

class _MoneiiAiScreenState extends ConsumerState<MoneiiAiScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty) return;
    _controller.clear();
    await ref.read(moneiiAiProvider.notifier).sendPrompt(prompt);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final purchases = ref.watch(revenueCatProvider);
    final state = ref.watch(moneiiAiProvider);
    final notifier = ref.read(moneiiAiProvider.notifier);
    final now = DateTime.now();
    final selectedMonth =
        state.selectedMonthStart ?? DateTime(now.year, now.month);
    final isCurrentMonthSelected =
        selectedMonth.year == now.year && selectedMonth.month == now.month;
    final isEligible =
        profile?.planTier == 'premium' ||
        profile?.isPremiumPlus == true ||
        purchases.hasMoneiiPro ||
        purchases.hasMoneiiProPlus;

    ref.listen<MoneiiAiState>(moneiiAiProvider, (previous, next) {
      final message = next.errorMessage;
      if (message == null ||
          message.isEmpty ||
          message == previous?.errorMessage) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
      notifier.clearError();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Zora')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: !isEligible
                ? _LockedMoneiiAi(
                    onUpgrade: () => showPremiumFeatureGate(
                      context,
                      feature: PremiumFeatureKey.aiFinancialCoach,
                      isPremium: false,
                    ),
                  )
                : Column(
                    children: [
                      if (state.isBootstrapping)
                        const LinearProgressIndicator(minHeight: 2),
                      if (state.isBootstrapping) const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _MonthSelector(
                          months: state.availableMonths,
                          selectedMonth: selectedMonth,
                          onSelected: notifier.selectMonth,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _UsageStrip(
                          planTier: profile?.planTier ?? state.planTier,
                          dailyUsed: state.dailyUsed,
                          dailyLimit: state.dailyLimit,
                          monthlyUsed: state.monthlyUsed,
                          monthlyLimit: state.monthlyLimit,
                        ),
                      ),
                      if (!isCurrentMonthSelected) ...[
                        const SizedBox(height: 6),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Read-only month. Switch to current month to send new questions.',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _QuickPrompts(
                        enabled: isCurrentMonthSelected,
                        onTap: (value) {
                          _controller.text = value;
                          _send();
                        },
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight.withValues(
                              alpha: 0.30,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.glassBorder.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                            itemCount: state.messages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = state.messages[index];
                              final isUser = item.role == 'user';
                              return Align(
                                alignment: isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 560,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? AppColors.primary.withValues(
                                            alpha: 0.26,
                                          )
                                        : AppColors.surface.withValues(
                                            alpha: 0.95,
                                          ),
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(14),
                                      topRight: const Radius.circular(14),
                                      bottomLeft: Radius.circular(isUser ? 14 : 6),
                                      bottomRight: Radius.circular(isUser ? 6 : 14),
                                    ),
                                    border: Border.all(
                                      color: isUser
                                          ? AppColors.primary.withValues(
                                              alpha: 0.55,
                                            )
                                          : AppColors.glassBorder.withValues(
                                              alpha: 0.75,
                                            ),
                                    ),
                                  ),
                                  child: Text(
                                    item.text,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 3,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) {
                                if (isCurrentMonthSelected) _send();
                              },
                              enabled: isCurrentMonthSelected,
                              decoration: InputDecoration(
                                hintText:
                                    isCurrentMonthSelected
                                    ? 'Ask anything about your money...'
                                    : 'Read-only month selected. Switch to current month to ask.',
                                filled: true,
                                fillColor: AppColors.surfaceLight.withValues(
                                  alpha: 0.55,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: AppColors.glassBorder.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: AppColors.glassBorder.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide(
                                    color: AppColors.primary.withValues(alpha: 0.7),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 54,
                            width: 54,
                            child: ElevatedButton(
                              onPressed: state.isLoading || !isCurrentMonthSelected
                                  ? null
                                  : _send,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: state.isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.months,
    required this.selectedMonth,
    required this.onSelected,
  });

  final List<DateTime> months;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM yyyy');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final month in months)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(formatter.format(month)),
                selected:
                    month.year == selectedMonth.year &&
                    month.month == selectedMonth.month,
                onSelected: (_) => onSelected(month),
                selectedColor: AppColors.primary.withValues(alpha: 0.28),
                backgroundColor: AppColors.surface.withValues(alpha: 0.6),
                side: BorderSide(
                  color:
                      month.year == selectedMonth.year &&
                          month.month == selectedMonth.month
                      ? AppColors.primary.withValues(alpha: 0.75)
                      : AppColors.glassBorder,
                ),
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight:
                      month.year == selectedMonth.year &&
                          month.month == selectedMonth.month
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LockedMoneiiAi extends StatelessWidget {
  const _LockedMoneiiAi({required this.onUpgrade});

  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, size: 32, color: AppColors.primary),
            const SizedBox(height: 10),
            const Text(
              'Zora is available on Premium plans.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Upgrade to ask personalized questions from your own spending and income data.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onUpgrade, child: const Text('Upgrade')),
          ],
        ),
      ),
    );
  }
}

class _UsageStrip extends StatelessWidget {
  const _UsageStrip({
    required this.planTier,
    required this.dailyUsed,
    required this.dailyLimit,
    required this.monthlyUsed,
    required this.monthlyLimit,
  });

  final String planTier;
  final int dailyUsed;
  final int? dailyLimit;
  final int monthlyUsed;
  final int monthlyLimit;

  @override
  Widget build(BuildContext context) {
    final planLabel = switch (planTier) {
      'premium_plus' => 'Premium+',
      'premium' => 'Premium',
      _ => 'Free',
    };

    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        Text(
          'Plan: $planLabel',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        Text(
          dailyLimit != null ? 'Today: $dailyUsed/$dailyLimit' : 'Today: $dailyUsed',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        if (monthlyLimit > 0)
          Text(
            'Month: $monthlyUsed/$monthlyLimit',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({required this.onTap, required this.enabled});

  final ValueChanged<String> onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget prompt(String value) {
      return InkWell(
        onTap: enabled ? () => onTap(value) : null,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: enabled ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: enabled ? AppColors.textSecondary : AppColors.textMuted,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          prompt('Where did I overspend this month?'),
          const SizedBox(width: 8),
          prompt('How much income came in this month?'),
          const SizedBox(width: 8),
          prompt('Give me 3 savings suggestions.'),
        ],
      ),
    );
  }
}
