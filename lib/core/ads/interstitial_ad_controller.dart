import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:moneii_manager/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InterstitialAdsState {
  const InterstitialAdsState({
    this.isSupported = false,
    this.isLoaded = false,
    this.isLoading = false,
  });

  final bool isSupported;
  final bool isLoaded;
  final bool isLoading;

  InterstitialAdsState copyWith({
    bool? isSupported,
    bool? isLoaded,
    bool? isLoading,
  }) {
    return InterstitialAdsState(
      isSupported: isSupported ?? this.isSupported,
      isLoaded: isLoaded ?? this.isLoaded,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final interstitialAdControllerProvider =
    StateNotifierProvider<InterstitialAdController, InterstitialAdsState>(
      (ref) => InterstitialAdController(ref),
    );

class InterstitialAdController extends StateNotifier<InterstitialAdsState> {
  InterstitialAdController(this._ref) : super(const InterstitialAdsState()) {
    state = state.copyWith(isSupported: _isSupportedPlatform);
  }

  final Ref _ref;
  InterstitialAd? _ad;

  static const _androidProductionAdUnit =
      'ca-app-pub-3454724051912655/7050150422';
  static const _androidTestAdUnit = 'ca-app-pub-3940256099942544/1033173712';

  static const _txnCountKey = 'ad_txn_success_count';
  static const _shownDateKey = 'ad_interstitial_shown_date';
  static const _shownCountKey = 'ad_interstitial_shown_count';
  static const _lastShownMsKey = 'ad_interstitial_last_shown_ms';

  static const _showEveryNSuccessfulTxns = 3;
  static const _dailyCap = 6;
  static const _cooldownSeconds = 120;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String? get _adUnitId {
    if (!_isSupportedPlatform) return null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return kDebugMode ? _androidTestAdUnit : _androidProductionAdUnit;
    }
    // iOS units are not configured yet for this app.
    return null;
  }

  Future<void> preload() async {
    final adUnitId = _adUnitId;
    if (adUnitId == null) return;
    if (_ad != null || state.isLoading) return;

    state = state.copyWith(isLoading: true, isLoaded: false);
    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          state = state.copyWith(isLoading: false, isLoaded: true);
        },
        onAdFailedToLoad: (_) {
          _ad = null;
          state = state.copyWith(isLoading: false, isLoaded: false);
        },
      ),
    );
  }

  Future<void> registerSuccessfulTransaction({required bool isFreeUser}) async {
    if (!isFreeUser || !_isSupportedPlatform) return;

    final prefs = _ref.read(sharedPreferencesProvider);
    final todayKey = _dateKey(DateTime.now());
    await _rolloverDailyCountersIfNeeded(prefs, todayKey: todayKey);

    final successfulCount = (prefs.getInt(_txnCountKey) ?? 0) + 1;
    await prefs.setInt(_txnCountKey, successfulCount);

    if (successfulCount % _showEveryNSuccessfulTxns != 0) {
      await preload();
      return;
    }

    final lastShownMs = prefs.getInt(_lastShownMsKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds = (nowMs - lastShownMs) / 1000;
    if (elapsedSeconds < _cooldownSeconds) {
      await preload();
      return;
    }

    final shownToday = prefs.getInt(_shownCountKey) ?? 0;
    if (shownToday >= _dailyCap) {
      await preload();
      return;
    }

    final ad = _ad;
    if (ad == null) {
      await preload();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _ad = null;
        state = state.copyWith(isLoaded: false);
        await _markShown();
        await preload();
      },
      onAdFailedToShowFullScreenContent: (ad, _) async {
        ad.dispose();
        _ad = null;
        state = state.copyWith(isLoaded: false);
        await preload();
      },
    );

    ad.show();
  }

  Future<void> _markShown() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final todayKey = _dateKey(DateTime.now());
    await _rolloverDailyCountersIfNeeded(prefs, todayKey: todayKey);

    final shownToday = prefs.getInt(_shownCountKey) ?? 0;
    await prefs.setInt(_shownCountKey, shownToday + 1);
    await prefs.setInt(_lastShownMsKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_txnCountKey, 0);
  }

  Future<void> _rolloverDailyCountersIfNeeded(
    SharedPreferences prefs, {
    required String todayKey,
  }) async {
    final previousDay = prefs.getString(_shownDateKey);
    if (previousDay == todayKey) return;
    await prefs.setString(_shownDateKey, todayKey);
    await prefs.setInt(_shownCountKey, 0);
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }
}
