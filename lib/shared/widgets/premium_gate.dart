import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/premium/premium_features.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/subscriptions/presentation/providers/revenuecat_provider.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

Future<void> showPremiumFeatureGate(
  BuildContext context, {
  required PremiumFeatureKey feature,
  required bool isPremium,
}) async {
  final meta = premiumMeta(feature);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (bottomSheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.lock_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      meta.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                meta.description,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(bottomSheetContext);
                    if (isPremium) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${meta.title} is coming soon for Premium users.',
                          ),
                        ),
                      );
                      return;
                    }
                    _handleUpgradeTap(context, feature: meta.title);
                  },
                  child: Text(isPremium ? 'Coming Soon' : 'Upgrade to Premium'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _handleUpgradeTap(
  BuildContext context, {
  required String feature,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final notifier = container.read(revenueCatProvider.notifier);
  final state = container.read(revenueCatProvider);
  final messenger = ScaffoldMessenger.of(context);

  if (!state.isSupported || !state.isConfigured) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('In-app purchases are not configured on this platform yet.'),
      ),
    );
    return;
  }

  final result = await notifier.presentPaywall();
  switch (result) {
    case PaywallResult.purchased:
    case PaywallResult.restored:
      container.invalidate(profileProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Premium unlocked. You can now use $feature.')),
      );
      break;
    case PaywallResult.cancelled:
      messenger.showSnackBar(
        const SnackBar(content: Text('Purchase cancelled.')),
      );
      break;
    case PaywallResult.error:
      messenger.showSnackBar(
        const SnackBar(content: Text('Purchase failed. Please try again.')),
      );
      break;
    case PaywallResult.notPresented:
      container.invalidate(profileProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('You already have active premium access.')),
      );
      break;
    case null:
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open paywall right now.')),
      );
      break;
  }
}
