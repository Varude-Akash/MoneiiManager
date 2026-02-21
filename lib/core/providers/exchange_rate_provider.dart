import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/core/utils/currency_utils.dart';

class ExchangeRateSnapshot {
  const ExchangeRateSnapshot({required this.usdRates, required this.fetchedAt});

  final Map<String, double> usdRates;
  final DateTime fetchedAt;
}

final exchangeRatesProvider = FutureProvider<ExchangeRateSnapshot>((ref) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  try {
    final response = await dio.get<Map<String, dynamic>>(
      'https://open.er-api.com/v6/latest/USD',
    );
    final data = response.data ?? <String, dynamic>{};
    final ratesRaw = data['rates'];

    if (ratesRaw is Map<String, dynamic>) {
      final rates = <String, double>{};
      for (final entry in ratesRaw.entries) {
        final value = entry.value;
        if (value is num) {
          rates[entry.key] = value.toDouble();
        }
      }

      if (rates.isNotEmpty) {
        rates['USD'] = 1.0;
        return ExchangeRateSnapshot(usdRates: rates, fetchedAt: DateTime.now());
      }
    }
  } catch (_) {
    // Fallback to static rates when the FX API is unavailable.
  }

  return ExchangeRateSnapshot(
    usdRates: CurrencyUtils.defaultUsdRates,
    fetchedAt: DateTime.now(),
  );
});

final supportedExchangeRatesProvider = Provider<Map<String, double>>((ref) {
  return ref.watch(exchangeRatesProvider).valueOrNull?.usdRates ??
      CurrencyUtils.defaultUsdRates;
});
