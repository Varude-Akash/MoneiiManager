import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:uuid/uuid.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/budgets/domain/entities/budget.dart';
import 'package:moneii_manager/features/budgets/presentation/providers/budget_provider.dart';
import 'package:moneii_manager/features/budgets/presentation/services/ai_budget_service.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/category_provider.dart';
import 'package:moneii_manager/features/subscriptions/presentation/providers/revenuecat_provider.dart';

class AiBudgetSuggestionsSheet extends ConsumerStatefulWidget {
  const AiBudgetSuggestionsSheet({
    super.key,
    required this.categoryAverages,
    required this.monthlyIncomeAvg,
  });

  /// Each map: {'CategoryName': avgMonthlySpend}
  final List<Map<String, double>> categoryAverages;
  final double monthlyIncomeAvg;

  static Future<void> show(
    BuildContext context, {
    required List<Map<String, double>> categoryAverages,
    required double monthlyIncomeAvg,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AiBudgetSuggestionsSheet(
        categoryAverages: categoryAverages,
        monthlyIncomeAvg: monthlyIncomeAvg,
      ),
    );
  }

  @override
  ConsumerState<AiBudgetSuggestionsSheet> createState() =>
      _AiBudgetSuggestionsSheetState();
}

class _AiBudgetSuggestionsSheetState
    extends ConsumerState<AiBudgetSuggestionsSheet> {
  List<AiBudgetSuggestion>? _suggestions;
  String? _error;
  bool _isLoading = true;

  // Per-suggestion state: accepted/skipped + editable amount
  late List<bool> _accepted;
  late List<bool> _skipped;
  late List<TextEditingController> _amountControllers;
  bool _isAcceptingAll = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    for (final c in _amountControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = ref.read(profileProvider).valueOrNull;
      final currency = profile?.currencyPreference ?? 'USD';
      final service = AiBudgetService();
      final suggestions = await service.getSuggestions(
        categoryAverages: widget.categoryAverages,
        monthlyIncomeAverage: widget.monthlyIncomeAvg,
        currency: currency,
      );
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _accepted = List.filled(suggestions.length, false);
          _skipped = List.filled(suggestions.length, false);
          _amountControllers = suggestions
              .map((s) => TextEditingController(
                    text: s.suggestedAmount.toStringAsFixed(2),
                  ))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptSuggestion(int index) async {
    final suggestions = _suggestions;
    if (suggestions == null) return;
    final suggestion = suggestions[index];
    final amount =
        double.tryParse(_amountControllers[index].text.trim()) ??
            suggestion.suggestedAmount;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final profile = ref.read(profileProvider).valueOrNull;
    final currency = profile?.currencyPreference ?? 'USD';

    // Try to resolve category id from categories
    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final matchedCategory = categories.firstWhere(
      (c) =>
          c.name.toLowerCase() ==
          suggestion.categoryName.toLowerCase(),
      orElse: () => categories.isNotEmpty ? categories.first : throw Exception('No categories'),
    );

    final budget = Budget(
      id: '',
      userId: user.id,
      categoryId: matchedCategory.id,
      categoryName: suggestion.categoryName,
      amount: amount,
      currency: currency,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await ref.read(budgetActionsProvider.notifier).upsert(budget);

    // Record AI usage
    try {
      final client = ref.read(supabaseClientProvider);
      await client.from('ai_assistant_requests').insert({
        'user_id': user.id,
        'prompt': 'ai_budget_suggestion:${suggestion.categoryName}',
        'response': 'accepted:${amount.toStringAsFixed(2)}',
        'status': 'success',
      });
    } catch (_) {}

    setState(() => _accepted[index] = true);
  }

  Future<void> _acceptAll() async {
    final suggestions = _suggestions;
    if (suggestions == null) return;
    setState(() => _isAcceptingAll = true);
    try {
      for (var i = 0; i < suggestions.length; i++) {
        if (!_skipped[i] && !_accepted[i]) {
          await _acceptSuggestion(i);
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isAcceptingAll = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final purchases = ref.watch(revenueCatProvider);
    final isPremium = profile?.planTier == 'premium' ||
        profile?.planTier == 'premium_plus' ||
        purchases.hasMoneiiPro ||
        purchases.hasMoneiiProPlus;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.glassBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'AI Budget Suggestions',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Iconsax.close_circle,
                            color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: !isPremium
                  ? _UpgradePrompt()
                  : _isLoading
                      ? _LoadingShimmer()
                      : _error != null
                          ? _ErrorView(
                              error: _error!,
                              onRetry: _loadSuggestions,
                            )
                          : _SuggestionList(
                              suggestions: _suggestions ?? [],
                              accepted: _accepted,
                              skipped: _skipped,
                              amountControllers: _amountControllers,
                              onAccept: _acceptSuggestion,
                              onSkip: (i) =>
                                  setState(() => _skipped[i] = true),
                              scrollController: scrollController,
                            ),
            ),

            // Accept All
            if (isPremium &&
                !_isLoading &&
                _error == null &&
                (_suggestions?.isNotEmpty ?? false))
              Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: ElevatedButton(
                  onPressed: _isAcceptingAll ? null : _acceptAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isAcceptingAll
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Accept All Suggestions',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.suggestions,
    required this.accepted,
    required this.skipped,
    required this.amountControllers,
    required this.onAccept,
    required this.onSkip,
    required this.scrollController,
  });

  final List<AiBudgetSuggestion> suggestions;
  final List<bool> accepted;
  final List<bool> skipped;
  final List<TextEditingController> amountControllers;
  final void Function(int) onAccept;
  final void Function(int) onSkip;
  final ScrollController scrollController;

  Color _difficultyColor(String d) {
    return switch (d) {
      'easy' => AppColors.accentGreen,
      'challenging' => AppColors.error,
      _ => AppColors.accentOrange,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: suggestions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = suggestions[i];
        final isAccepted = accepted[i];
        final isSkipped = skipped[i];

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isSkipped ? 0.4 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isAccepted
                  ? AppColors.accentGreen.withValues(alpha: 0.08)
                  : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAccepted
                    ? AppColors.accentGreen.withValues(alpha: 0.4)
                    : AppColors.glassBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.categoryName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _difficultyColor(s.difficulty)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s.difficulty,
                        style: TextStyle(
                          color: _difficultyColor(s.difficulty),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  s.reason,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),

                // Editable amount
                Row(
                  children: [
                    const Text(
                      'Budget: ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: amountControllers[i],
                        enabled: !isAccepted && !isSkipped,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.primary),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.surfaceLight),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Accept / Skip buttons
                    if (isAccepted)
                      const Icon(
                        Iconsax.tick_circle,
                        color: AppColors.accentGreen,
                        size: 22,
                      )
                    else if (!isSkipped) ...[
                      IconButton(
                        onPressed: () => onAccept(i),
                        icon: const Icon(
                          Iconsax.tick_circle,
                          color: AppColors.accentGreen,
                          size: 22,
                        ),
                        tooltip: 'Accept',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => onSkip(i),
                        icon: const Icon(
                          Iconsax.close_circle,
                          color: AppColors.textMuted,
                          size: 22,
                        ),
                        tooltip: 'Skip',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceLight,
      highlightColor: AppColors.card,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.warning_2, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Iconsax.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradePrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✨', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Premium Feature',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI budget suggestions are available to Moneii Pro members. Upgrade to get personalized budgets.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Upgrade to Pro'),
            ),
          ],
        ),
      ),
    );
  }
}
