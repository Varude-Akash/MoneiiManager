import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/wrapped/presentation/providers/wrapped_provider.dart';

class WrappedScreen extends ConsumerWidget {
  const WrappedScreen({super.key, this.wrappedData});

  static Color _personalityColor(WrappedPersonality p) {
    return switch (p) {
      WrappedPersonality.smartSaver => const Color(0xFF10B981),
      WrappedPersonality.livingItUp => const Color(0xFFEC4899),
      WrappedPersonality.foodieFirst => const Color(0xFFFF6B6B),
      WrappedPersonality.weekendWarrior => const Color(0xFFF59E0B),
      WrappedPersonality.entertainmentJunkie => const Color(0xFF8B5CF6),
      WrappedPersonality.shopaholic => const Color(0xFFA78BFA),
      WrappedPersonality.wanderlust => const Color(0xFFF97316),
      WrappedPersonality.wellnessWarrior => const Color(0xFF06B6D4),
      WrappedPersonality.billMaster => const Color(0xFF64748B),
      WrappedPersonality.balancedSpender => const Color(0xFF7C3AED),
    };
  }

  final WrappedData? wrappedData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wrappedAsync = ref.watch(wrappedDataProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final currency = profile?.currencyPreference ?? 'USD';
    final fmt = NumberFormat.currency(
      symbol: NumberFormat.currency(name: currency).currencySymbol,
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: wrappedAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _ErrorView(onClose: () => Navigator.of(context).pop()),
        data: (wrapped) {
          if (wrapped == null) {
            return _NullView(onClose: () => Navigator.of(context).pop());
          }
          final color = _personalityColor(wrapped.personality);
          final monthName = DateFormat.MMMM()
              .format(DateTime(wrapped.year, wrapped.month));

          return Stack(
            children: [
              // Gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.25),
                      AppColors.background,
                      AppColors.background,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),

              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Close button
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Iconsax.close_circle,
                              color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Month label
                      Text(
                        '$monthName ${wrapped.year} Wrapped',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Emoji
                      Text(
                        wrapped.emoji,
                        style: const TextStyle(fontSize: 96),
                      ),
                      const SizedBox(height: 12),

                      // Personality title
                      Text(
                        wrapped.title,
                        style: TextStyle(
                          color: color,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Stat chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatChip(
                            label: 'Spent',
                            value: fmt.format(wrapped.totalExpenses),
                            color: color,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'Top Cat',
                            value:
                                '${(wrapped.topCategoryPct * 100).round()}%',
                            color: AppColors.accentOrange,
                          ),
                          const SizedBox(width: 8),
                          _StatChip(
                            label: 'Saved',
                            value:
                                '${(wrapped.savingsRate * 100).round()}%',
                            color: AppColors.accentGreen,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Headline
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: color.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          wrapped.headline,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Insight
                      Text(
                        wrapped.insight,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Challenge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '🎯',
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                wrapped.challenge,
                                style: const TextStyle(
                                  color: AppColors.accentOrange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // AI Narrative
                      if (wrapped.aiNarrative != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.15),
                                AppColors.accent.withValues(alpha: 0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text('✨',
                                      style: TextStyle(fontSize: 16)),
                                  SizedBox(width: 6),
                                  Text(
                                    'AI Insight',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                wrapped.aiNarrative!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Share button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Screenshot to share! 📸'),
                              ),
                            );
                          },
                          icon: const Icon(Iconsax.share),
                          label: const Text('Share My Wrapped'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('😕', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            'Could not load your Wrapped',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onClose, child: const Text('Close')),
        ],
      ),
    );
  }
}

class _NullView extends StatelessWidget {
  const _NullView({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📊', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Not enough data yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Log at least 5 expenses in a month to unlock your Wrapped.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onClose, child: const Text('Got it')),
          ],
        ),
      ),
    );
  }
}
