import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/premium/premium_features.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/moneii_ai/presentation/providers/moneii_ai_provider.dart';
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
    final state = ref.watch(moneiiAiProvider);
    final notifier = ref.read(moneiiAiProvider.notifier);
    final isEligible = profile?.planTier == 'premium' || profile?.isPremiumPlus == true;

    ref.listen<MoneiiAiState>(moneiiAiProvider, (previous, next) {
      final message = next.errorMessage;
      if (message == null || message.isEmpty || message == previous?.errorMessage) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
      notifier.clearError();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Moneii AI')),
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
                      _UsageStrip(
                        planTier: profile?.planTier ?? state.planTier,
                        dailyUsed: state.dailyUsed,
                        dailyLimit: state.dailyLimit,
                        monthlyUsed: state.monthlyUsed,
                        monthlyLimit: state.monthlyLimit,
                      ),
                      const SizedBox(height: 10),
                      _QuickPrompts(onTap: (value) {
                        _controller.text = value;
                        _send();
                      }),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: state.messages.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = state.messages[index];
                              final isUser = item.role == 'user';
                              return Align(
                                alignment: isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 520),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? AppColors.primary.withValues(alpha: 0.25)
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isUser
                                          ? AppColors.primary.withValues(alpha: 0.45)
                                          : AppColors.glassBorder,
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
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 3,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(
                                hintText:
                                    'Ask about spending trends, income, transfers, or suggestions...',
                                filled: true,
                                fillColor: AppColors.surfaceLight.withValues(alpha: 0.4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: AppColors.glassBorder.withValues(alpha: 0.8),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: AppColors.glassBorder.withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: state.isLoading ? null : _send,
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
              'Moneii AI is available on Premium plans.',
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _UsageChip(label: 'Plan', value: planLabel),
          if (dailyLimit != null)
            _UsageChip(label: 'Today', value: '$dailyUsed/$dailyLimit')
          else
            _UsageChip(label: 'Today', value: '$dailyUsed'),
          _UsageChip(label: 'Month', value: '$monthlyUsed/$monthlyLimit'),
        ],
      ),
    );
  }
}

class _UsageChip extends StatelessWidget {
  const _UsageChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    Widget prompt(String value) {
      return InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          prompt('Where did I overspend this month?'),
          prompt('How much income came in this month?'),
          prompt('Give me 3 savings suggestions.'),
        ],
      ),
    );
  }
}
