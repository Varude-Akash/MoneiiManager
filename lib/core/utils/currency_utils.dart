import 'package:intl/intl.dart';

class CurrencyUtils {
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

  static String _getSymbol(String currency) {
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
}
