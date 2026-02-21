enum PremiumFeatureKey {
  aiSpendingInsights,
  investmentSuggestions,
  smartBudgetRecommendations,
  expensePredictions,
  receiptScanner,
  exportReports,
  multiCurrency,
  customCategories,
  sharedExpenses,
  aiFinancialCoach,
}

class PremiumFeatureMeta {
  const PremiumFeatureMeta({
    required this.key,
    required this.title,
    required this.description,
  });

  final PremiumFeatureKey key;
  final String title;
  final String description;
}

const premiumFeatureCatalog = <PremiumFeatureMeta>[
  PremiumFeatureMeta(
    key: PremiumFeatureKey.aiSpendingInsights,
    title: 'AI Spending Insights',
    description: 'See smart patterns and suggestions from your spending behavior.',
  ),
  PremiumFeatureMeta(
    key: PremiumFeatureKey.investmentSuggestions,
    title: 'Investment Suggestions',
    description: 'Get guided suggestions from your savings and spending signals.',
  ),
  PremiumFeatureMeta(
    key: PremiumFeatureKey.smartBudgetRecommendations,
    title: 'Smart Budget Recommendations',
    description: 'Auto-generated budgets per category based on your history.',
  ),
  PremiumFeatureMeta(
    key: PremiumFeatureKey.expensePredictions,
    title: 'Expense Predictions',
    description: 'Forecast upcoming spends from recurring patterns.',
  ),
  PremiumFeatureMeta(
    key: PremiumFeatureKey.receiptScanner,
    title: 'Receipt Scanner',
    description: 'Scan receipts and auto-fill transactions.',
  ),
  PremiumFeatureMeta(
    key: PremiumFeatureKey.exportReports,
    title: 'Export Reports',
    description: 'Export monthly and yearly reports as PDF or CSV.',
  ),
  PremiumFeatureMeta(
    key: PremiumFeatureKey.multiCurrency,
    title: 'Multi-currency',
    description: 'Advanced cross-currency support and history controls.',
  ),
  PremiumFeatureMeta(
    key: PremiumFeatureKey.customCategories,
    title: 'Custom Categories',
    description: 'Create your own categories and subcategories.',
  ),
  PremiumFeatureMeta(
    key: PremiumFeatureKey.sharedExpenses,
    title: 'Shared Expenses',
    description: 'Split and track expenses with friends.',
  ),
  PremiumFeatureMeta(
    key: PremiumFeatureKey.aiFinancialCoach,
    title: 'AI Financial Coach',
    description: 'Ask finance questions and get personalized guidance.',
  ),
];

PremiumFeatureMeta premiumMeta(PremiumFeatureKey key) {
  return premiumFeatureCatalog.firstWhere((feature) => feature.key == key);
}

