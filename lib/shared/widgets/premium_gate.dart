import 'package:flutter/material.dart';
import 'package:moneii_manager/config/theme.dart';
import 'package:moneii_manager/core/premium/premium_features.dart';

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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isPremium
                              ? '${meta.title} is coming soon for Premium users.'
                              : 'Upgrade to Premium to unlock ${meta.title}.',
                        ),
                      ),
                    );
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

