// ============================================
// TimurLang - Currency Conversion Utilities
// ============================================

import '../config/constants.dart';

class CurrencyUtils {
  static Map<String, double> _rates = Map.from(AppConstants.defaultCurrencyRates);

  /// Update rates (when online)
  static void updateRates(Map<String, double> newRates) {
    _rates = newRates;
  }

  /// Convert from IDR to target currency
  static double convertFromIDR(double amountIDR, String targetCurrency) {
    final rate = _rates[targetCurrency] ?? 1.0;
    return amountIDR * rate;
  }

  /// Convert between any two currencies
  static double convert(double amount, String from, String to) {
    if (from == to) return amount;
    // Convert to IDR first, then to target
    final fromRate = _rates[from] ?? 1.0;
    final toRate = _rates[to] ?? 1.0;
    final amountInIDR = amount / fromRate;
    return amountInIDR * toRate;
  }

  /// Format currency with symbol
  static String formatCurrency(double amount, String currency) {
    final symbols = {
      'IDR': 'Rp',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
    };
    final symbol = symbols[currency] ?? currency;

    if (currency == 'IDR') {
      return '$symbol ${_formatNumber(amount.round().toDouble())}';
    }
    return '$symbol ${amount.toStringAsFixed(2)}';
  }

  static String _formatNumber(double number) {
    final str = number.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  /// Get available currencies
  static List<String> get availableCurrencies => _rates.keys.toList();

  /// Get current rate for display
  static double getRate(String currency) => _rates[currency] ?? 1.0;
}
