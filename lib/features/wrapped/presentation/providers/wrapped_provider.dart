import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/expenses/presentation/providers/expense_provider.dart';
import 'package:moneii_manager/features/expenses/domain/entities/expense.dart';

// ─── Enum ─────────────────────────────────────────────────────────────────────

enum WrappedPersonality {
  smartSaver,
  livingItUp,
  foodieFirst,
  weekendWarrior,
  entertainmentJunkie,
  shopaholic,
  wanderlust,
  wellnessWarrior,
  billMaster,
  balancedSpender,
}

// ─── WrappedData ──────────────────────────────────────────────────────────────

class WrappedData {
  const WrappedData({
    required this.personality,
    required this.title,
    required this.emoji,
    required this.totalExpenses,
    required this.totalIncome,
    required this.savingsRate,
    required this.topCategory,
    required this.topCategoryPct,
    required this.month,
    required this.year,
    required this.headline,
    required this.insight,
    required this.challenge,
    this.aiNarrative,
  });

  final WrappedPersonality personality;
  final String title;
  final String emoji;
  final double totalExpenses;
  final double totalIncome;
  final double savingsRate;
  final String topCategory;
  final double topCategoryPct;
  final int month;
  final int year;
  final String headline;
  final String insight;
  final String challenge;
  final String? aiNarrative;
}

// ─── Hardcoded insight/challenge strings ─────────────────────────────────────

String _insightFor(WrappedPersonality p) {
  return switch (p) {
    WrappedPersonality.smartSaver =>
      'Okay, you literally ate rice for 30 days and still looked good doing it. Respect. 🙌',
    WrappedPersonality.livingItUp =>
      'YOLO is a lifestyle, not a budgeting strategy. But hey, at least you had fun. 😅',
    WrappedPersonality.foodieFirst =>
      'Your stomach is your love language. No notes, we respect it. 🍜',
    WrappedPersonality.weekendWarrior =>
      'Monday-you is always paying for Friday-you\'s decisions. Classic origin story. 🎉',
    WrappedPersonality.entertainmentJunkie =>
      'You basically funded an entire streaming platform. You deserve a thank-you card. 🎬',
    WrappedPersonality.shopaholic =>
      'Add to cart. Checkout. Regret. Repeat. You\'re keeping the economy alive. 🛍️',
    WrappedPersonality.wanderlust =>
      'The world is your playground and your bank account is paying the entry fee. ✈️',
    WrappedPersonality.wellnessWarrior =>
      'Investing in your health hits different when you check the receipts. 💪',
    WrappedPersonality.billMaster =>
      'Subscriptions and bills are basically rent for your digital life at this point. 📋',
    WrappedPersonality.balancedSpender =>
      'You\'re out here living the balanced life that finance gurus preach. A legend. ⚖️',
  };
}

String _challengeFor(WrappedPersonality p) {
  return switch (p) {
    WrappedPersonality.smartSaver =>
      'Challenge: Treat yourself to something nice. You earned it — for real.',
    WrappedPersonality.livingItUp =>
      'Challenge: Try a no-spend weekend. Just one. Promise it\'s not that bad.',
    WrappedPersonality.foodieFirst =>
      'Challenge: Cook at home 3x this week. Your future self will thank you.',
    WrappedPersonality.weekendWarrior =>
      'Challenge: Plan a free-activity weekend. Nature is free and lowkey iconic.',
    WrappedPersonality.entertainmentJunkie =>
      'Challenge: Audit your subscriptions. Cancel one you forgot you even had.',
    WrappedPersonality.shopaholic =>
      'Challenge: Add to wishlist instead of cart for 7 days. Then see what you still want.',
    WrappedPersonality.wanderlust =>
      'Challenge: Plan a local staycation. Discover your city like a tourist.',
    WrappedPersonality.wellnessWarrior =>
      'Challenge: Find one free workout routine and stick to it for 2 weeks.',
    WrappedPersonality.billMaster =>
      'Challenge: Call one service provider and negotiate a lower rate this month.',
    WrappedPersonality.balancedSpender =>
      'Challenge: Boost savings by 5% this month. You\'re already killing it.',
  };
}

// ─── wrappedDataProvider ──────────────────────────────────────────────────────

final wrappedDataProvider = FutureProvider<WrappedData?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  final client = ref.watch(supabaseClientProvider);

  final now = DateTime.now();
  // Previous month
  final prevMonth = now.month == 1 ? 12 : now.month - 1;
  final prevYear = now.month == 1 ? now.year - 1 : now.year;

  // Check cache first
  try {
    final cached = await client
        .from('monthly_wrapped')
        .select('*')
        .eq('user_id', user.id)
        .eq('month', prevMonth)
        .eq('year', prevYear)
        .maybeSingle();

    if (cached != null) {
      return _wrappedFromCacheRow(cached);
    }
  } catch (_) {
    // Cache miss or table doesn't exist — compute fresh.
  }

  // Fetch all expenses for previous month from provider
  final allExpenses = ref.watch(expensesProvider).valueOrNull ?? [];
  final prevMonthExpenses = allExpenses.where((e) {
    return e.expenseDate.year == prevYear &&
        e.expenseDate.month == prevMonth;
  }).toList();

  final expenses =
      prevMonthExpenses.where((e) => e.transactionType == 'expense').toList();
  final incomeList =
      prevMonthExpenses.where((e) => e.transactionType == 'income').toList();

  if (expenses.length < 5) return null;

  final totalExpenses =
      expenses.fold<double>(0, (sum, e) => sum + e.amount);
  final totalIncome =
      incomeList.fold<double>(0, (sum, e) => sum + e.amount);
  final savingsRate =
      totalIncome > 0 ? (totalIncome - totalExpenses) / totalIncome : -1.0;

  // Category breakdown
  final categoryTotals = <String, double>{};
  for (final e in expenses) {
    categoryTotals.update(
      e.categoryName,
      (v) => v + e.amount,
      ifAbsent: () => e.amount,
    );
  }
  final topEntry = categoryTotals.entries
      .reduce((a, b) => a.value >= b.value ? a : b);
  final topCategory = topEntry.key;
  final topCategoryPct =
      totalExpenses > 0 ? topEntry.value / totalExpenses : 0.0;

  // Weekend spending percentage
  double weekendSpend = 0;
  for (final e in expenses) {
    final wd = e.expenseDate.weekday;
    if (wd == DateTime.saturday || wd == DateTime.sunday) {
      weekendSpend += e.amount;
    }
  }
  final weekendPct =
      totalExpenses > 0 ? weekendSpend / totalExpenses : 0.0;

  // Personality assignment (priority order)
  WrappedPersonality personality;
  String title;
  String emoji;
  String headline;

  if (savingsRate >= 0.30) {
    personality = WrappedPersonality.smartSaver;
    title = 'Smart Saver';
    emoji = '💰';
    headline =
        'You saved ${(savingsRate * 100).round()}% of your income last month.';
  } else if (savingsRate < 0) {
    personality = WrappedPersonality.livingItUp;
    title = 'Living It Up';
    emoji = '🎭';
    headline = 'You spent more than you earned last month.';
  } else if (topCategoryPct >= 0.30 &&
      topCategory.toLowerCase().contains('food')) {
    personality = WrappedPersonality.foodieFirst;
    title = 'Foodie First';
    emoji = '🍜';
    headline =
        'You devoted ${(topCategoryPct * 100).round()}% of spending to $topCategory.';
  } else if (weekendPct >= 0.60) {
    personality = WrappedPersonality.weekendWarrior;
    title = 'Weekend Warrior';
    emoji = '🎉';
    headline = 'Over 60% of your spending happened on weekends.';
  } else if (topCategoryPct >= 0.20 &&
      topCategory.toLowerCase().contains('entertainment')) {
    personality = WrappedPersonality.entertainmentJunkie;
    title = 'Entertainment Junkie';
    emoji = '🎬';
    headline =
        'You devoted ${(topCategoryPct * 100).round()}% of spending to $topCategory.';
  } else if (topCategoryPct >= 0.25 &&
      topCategory.toLowerCase().contains('shopping')) {
    personality = WrappedPersonality.shopaholic;
    title = 'Shopaholic';
    emoji = '🛍️';
    headline =
        'You devoted ${(topCategoryPct * 100).round()}% of spending to $topCategory.';
  } else if (topCategoryPct >= 0.20 &&
      topCategory.toLowerCase().contains('travel')) {
    personality = WrappedPersonality.wanderlust;
    title = 'Wanderlust';
    emoji = '✈️';
    headline =
        'You devoted ${(topCategoryPct * 100).round()}% of spending to $topCategory.';
  } else if (topCategory.toLowerCase().contains('health')) {
    personality = WrappedPersonality.wellnessWarrior;
    title = 'Wellness Warrior';
    emoji = '💪';
    headline =
        'You invested ${(topCategoryPct * 100).round()}% of your spending in $topCategory.';
  } else if (topCategoryPct >= 0.40 &&
      topCategory.toLowerCase().contains('bill')) {
    personality = WrappedPersonality.billMaster;
    title = 'Bill Master';
    emoji = '📋';
    headline =
        'Bills took up ${(topCategoryPct * 100).round()}% of your spending last month.';
  } else {
    personality = WrappedPersonality.balancedSpender;
    title = 'Balanced Spender';
    emoji = '⚖️';
    headline = 'You kept your spending balanced across categories. Nice!';
  }

  final wrappedData = WrappedData(
    personality: personality,
    title: title,
    emoji: emoji,
    totalExpenses: totalExpenses,
    totalIncome: totalIncome,
    savingsRate: savingsRate < 0 ? 0 : savingsRate,
    topCategory: topCategory,
    topCategoryPct: topCategoryPct,
    month: prevMonth,
    year: prevYear,
    headline: headline,
    insight: _insightFor(personality),
    challenge: _challengeFor(personality),
  );

  // Save to cache
  try {
    await client.from('monthly_wrapped').upsert({
      'user_id': user.id,
      'month': prevMonth,
      'year': prevYear,
      'personality': personality.name,
      'title': title,
      'emoji': emoji,
      'total_expenses': totalExpenses,
      'total_income': totalIncome,
      'savings_rate': wrappedData.savingsRate,
      'top_category': topCategory,
      'top_category_pct': topCategoryPct,
      'headline': headline,
      'insight': wrappedData.insight,
      'challenge': wrappedData.challenge,
    }, onConflict: 'user_id,month,year');
  } catch (_) {
    // Cache save failed — that's fine.
  }

  return wrappedData;
});

WrappedData? _wrappedFromCacheRow(Map<String, dynamic> row) {
  try {
    final personalityName = row['personality'] as String? ?? 'balancedSpender';
    final personality = WrappedPersonality.values.firstWhere(
      (e) => e.name == personalityName,
      orElse: () => WrappedPersonality.balancedSpender,
    );
    return WrappedData(
      personality: personality,
      title: row['title'] as String? ?? '',
      emoji: row['emoji'] as String? ?? '⚖️',
      totalExpenses: (row['total_expenses'] as num?)?.toDouble() ?? 0,
      totalIncome: (row['total_income'] as num?)?.toDouble() ?? 0,
      savingsRate: (row['savings_rate'] as num?)?.toDouble() ?? 0,
      topCategory: row['top_category'] as String? ?? '',
      topCategoryPct: (row['top_category_pct'] as num?)?.toDouble() ?? 0,
      month: row['month'] as int? ?? 1,
      year: row['year'] as int? ?? 2024,
      headline: row['headline'] as String? ?? '',
      insight: row['insight'] as String? ?? _insightFor(personality),
      challenge: row['challenge'] as String? ?? _challengeFor(personality),
      aiNarrative: row['ai_narrative'] as String?,
    );
  } catch (_) {
    return null;
  }
}

// ─── wrappedShownProvider ─────────────────────────────────────────────────────

final wrappedShownProvider = StateProvider<bool>((ref) => false);
