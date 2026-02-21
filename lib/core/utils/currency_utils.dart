import 'package:intl/intl.dart';

class CurrencyUtils {
  static const List<String> supportedCurrencies = [
    'USD',
    'EUR',
    'GBP',
    'INR',
    'JPY',
  ];

  // Base rates: how much 1 USD equals in target currency.
  static const Map<String, double> defaultUsdRates = {
    'USD': 1.0,
    'EUR': 0.92,
    'GBP': 0.79,
    'INR': 83.0,
    'JPY': 150.0,
  };

  static String format(double amount, {String currency = 'USD'}) {
    final formatter = NumberFormat.currency(
      symbol: _getSymbol(currency),
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount, {String currency = 'USD'}) {
    if (amount >= 1000000) {
      return '${_getSymbol(currency)}${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${_getSymbol(currency)}${(amount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount, currency: currency);
  }

  static double convert(
    double amount, {
    required String fromCurrency,
    required String toCurrency,
    Map<String, double>? usdRates,
  }) {
    if (fromCurrency == toCurrency) return amount;

    final rates = usdRates ?? defaultUsdRates;
    final fromRate = rates[fromCurrency] ?? 1.0;
    final toRate = rates[toCurrency] ?? 1.0;

    // Convert to USD first, then to target currency.
    final amountInUsd = amount / fromRate;
    return amountInUsd * toRate;
  }

  static String symbolFor(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '\u20AC';
      case 'GBP':
        return '\u00A3';
      case 'INR':
        return '\u20B9';
      case 'JPY':
        return '\u00A5';
      default:
        return '\$';
    }
  }

  static String currencyLabel(String currency) {
    return '$currency (${symbolFor(currency)})';
  }

  static String _getSymbol(String currency) => symbolFor(currency);
}
