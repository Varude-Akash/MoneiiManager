import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/config/env.dart';
import 'package:moneii_manager/features/auth/domain/entities/app_user.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

const moneiiProEntitlement = 'Moneii Pro';

class RevenueCatState {
  const RevenueCatState({
    this.isSupported = false,
    this.isConfigured = false,
    this.isLoading = false,
    this.hasMoneiiPro = false,
    this.currentOfferingIdentifier,
    this.availablePackageIds = const <String>[],
    this.errorMessage,
  });

  final bool isSupported;
  final bool isConfigured;
  final bool isLoading;
  final bool hasMoneiiPro;
  final String? currentOfferingIdentifier;
  final List<String> availablePackageIds;
  final String? errorMessage;

  RevenueCatState copyWith({
    bool? isSupported,
    bool? isConfigured,
    bool? isLoading,
    bool? hasMoneiiPro,
    String? currentOfferingIdentifier,
    List<String>? availablePackageIds,
    String? errorMessage,
  }) {
    return RevenueCatState(
      isSupported: isSupported ?? this.isSupported,
      isConfigured: isConfigured ?? this.isConfigured,
      isLoading: isLoading ?? this.isLoading,
      hasMoneiiPro: hasMoneiiPro ?? this.hasMoneiiPro,
      currentOfferingIdentifier:
          currentOfferingIdentifier ?? this.currentOfferingIdentifier,
      availablePackageIds: availablePackageIds ?? this.availablePackageIds,
      errorMessage: errorMessage,
    );
  }
}

class RevenueCatNotifier extends StateNotifier<RevenueCatState> {
  RevenueCatNotifier(this._ref) : super(const RevenueCatState()) {
    _customerInfoListener = (customerInfo) async {
      await _updateFromCustomerInfo(customerInfo);
    };
  }

  final Ref _ref;
  late final CustomerInfoUpdateListener _customerInfoListener;
  bool _listenerAttached = false;
  AppUser? _currentUser;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> syncAuth(AppUser? user) async {
    _currentUser = user;
    if (!_isSupportedPlatform) {
      state = state.copyWith(
        isSupported: false,
        isConfigured: false,
        hasMoneiiPro: false,
        errorMessage: null,
      );
      return;
    }

    final apiKey = Env.revenueCatApiKey.trim();
    if (apiKey.isEmpty) {
      state = state.copyWith(
        isSupported: true,
        isConfigured: false,
        errorMessage: 'RevenueCat API key is missing.',
      );
      return;
    }

    try {
      if (!await Purchases.isConfigured) {
        final config = PurchasesConfiguration(apiKey)..appUserID = user?.id;
        await Purchases.configure(config);
      } else if (user != null) {
        await Purchases.logIn(user.id);
      }

      if (!_listenerAttached) {
        Purchases.addCustomerInfoUpdateListener(_customerInfoListener);
        _listenerAttached = true;
      }

      state = state.copyWith(isSupported: true, isConfigured: true, errorMessage: null);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSupported: true,
        isConfigured: false,
        errorMessage: _formatError(error),
      );
    }
  }

  Future<void> refresh() async {
    if (!state.isConfigured) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final info = await Purchases.getCustomerInfo();
      await _updateFromCustomerInfo(info);

      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      final ids = current?.availablePackages.map((p) => p.identifier).toList() ?? const <String>[];
      state = state.copyWith(
        isLoading: false,
        currentOfferingIdentifier: current?.identifier,
        availablePackageIds: ids,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: _formatError(error));
    }
  }

  Future<PaywallResult?> presentPaywall() async {
    if (!state.isConfigured) return null;
    try {
      final result = await RevenueCatUI.presentPaywallIfNeeded(moneiiProEntitlement);
      await refresh();
      return result;
    } catch (error) {
      state = state.copyWith(errorMessage: _formatError(error));
      return null;
    }
  }

  Future<void> restorePurchases() async {
    if (!state.isConfigured) return;
    try {
      final info = await Purchases.restorePurchases();
      await _updateFromCustomerInfo(info);
      await refresh();
    } catch (error) {
      state = state.copyWith(errorMessage: _formatError(error));
    }
  }

  Future<void> presentCustomerCenter() async {
    if (!state.isConfigured) return;
    try {
      await RevenueCatUI.presentCustomerCenter();
      await refresh();
    } catch (error) {
      state = state.copyWith(errorMessage: _formatError(error));
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<void> _updateFromCustomerInfo(CustomerInfo info) async {
    final hasPro = info.entitlements.active.containsKey(moneiiProEntitlement);
    state = state.copyWith(hasMoneiiPro: hasPro);
    await _syncProFlagToProfile(hasPro: hasPro);
  }

  Future<void> _syncProFlagToProfile({required bool hasPro}) async {
    final user = _currentUser;
    if (user == null) return;
    final client = _ref.read(supabaseClientProvider);
    final row = await client
        .from('profiles')
        .select('plan_tier, is_premium')
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) return;
    final currentTier = (row['plan_tier'] as String?) ?? 'free';
    final currentPremium = row['is_premium'] as bool? ?? false;

    String nextTier = currentTier;
    bool nextPremium = currentPremium;

    if (hasPro) {
      if (currentTier == 'free') {
        nextTier = 'premium';
        nextPremium = true;
      }
    } else {
      if (currentTier == 'premium') {
        nextTier = 'free';
        nextPremium = false;
      }
    }

    if (nextTier != currentTier || nextPremium != currentPremium) {
      await client
          .from('profiles')
          .update({'plan_tier': nextTier, 'is_premium': nextPremium})
          .eq('id', user.id);
      _ref.invalidate(profileProvider);
    }
  }

  String _formatError(Object error) {
    if (error is PurchasesError) {
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    if (_listenerAttached) {
      Purchases.removeCustomerInfoUpdateListener(_customerInfoListener);
      _listenerAttached = false;
    }
    super.dispose();
  }
}

final revenueCatProvider =
    StateNotifierProvider<RevenueCatNotifier, RevenueCatState>((ref) {
      final notifier = RevenueCatNotifier(ref);
      ref.listen<AsyncValue<AppUser?>>(authStateProvider, (previous, next) {
        notifier.syncAuth(next.valueOrNull);
      });
      notifier.syncAuth(ref.read(authStateProvider).valueOrNull);
      return notifier;
    });
