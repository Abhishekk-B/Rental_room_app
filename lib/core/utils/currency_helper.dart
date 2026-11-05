class CurrencyHelper {
  /// Converts integer paise to formatted Indian Rupee string (e.g. 350000 -> ₹3,500 or ₹3,500.50)
  /// Uses pure Dart Indian numbering system: 1,00,000 / 10,000 / 1,000
  static String formatPaise(int paise, {bool showSymbol = true, bool showDecimals = false}) {
    final bool isNegative = paise < 0;
    final int absPaise = paise.abs();
    final int rupees = absPaise ~/ 100;
    final int remainderPaise = absPaise % 100;

    final String rupeesFormatted = _formatIndianRupees(rupees);
    final String symbol = showSymbol ? '₹' : '';
    final String sign = isNegative ? '-' : '';

    if (showDecimals || remainderPaise != 0) {
      final String dec = remainderPaise.toString().padLeft(2, '0');
      return '$sign$symbol$rupeesFormatted.$dec';
    } else {
      return '$sign$symbol$rupeesFormatted';
    }
  }

  /// Formats an integer using Indian numbering format (e.g. 1234567 -> 12,34,567)
  static String _formatIndianRupees(int number) {
    final String s = number.toString();
    if (s.length <= 3) return s;

    // Last 3 digits
    final String lastThree = s.substring(s.length - 3);
    String remaining = s.substring(0, s.length - 3);

    final List<String> groups = [];
    while (remaining.length > 2) {
      groups.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      groups.insert(0, remaining);
    }

    return '${groups.join(',')},$lastThree';
  }

  /// Parses user rupee text input into integer paise.
  /// Handles "3500", "3,500", "3500.50", " ₹ 3500.75 "
  static int parseRupeesToPaise(String input) {
    if (input.trim().isEmpty) return 0;

    // Clean string from symbols, commas, spaces
    final cleaned = input.replaceAll('₹', '').replaceAll(',', '').trim();
    if (cleaned.isEmpty) return 0;

    final parts = cleaned.split('.');
    final int rupees = int.tryParse(parts[0]) ?? 0;

    int paise = 0;
    if (parts.length > 1) {
      String decimalPart = parts[1];
      if (decimalPart.length == 1) {
        decimalPart += '0';
      } else if (decimalPart.length > 2) {
        decimalPart = decimalPart.substring(0, 2);
      }
      paise = int.tryParse(decimalPart) ?? 0;
    }

    if (rupees < 0) {
      return (rupees * 100) - paise;
    }
    return (rupees * 100) + paise;
  }

  /// Converts paise to rupees string for text fields (e.g. 350000 -> "3500" or "3500.50")
  static String paiseToRupeesString(int paise) {
    if (paise % 100 == 0) {
      return (paise ~/ 100).toString();
    } else {
      final double val = paise / 100.0;
      return val.toStringAsFixed(2);
    }
  }

  /// Formats meter units (stored in centi-units: 13050 -> "130.5 units" or 13000 -> "130 units")
  static String formatCentiunits(int centiunits) {
    final double units = centiunits / 100.0;
    if (centiunits % 100 == 0) {
      return '${units.toInt()} units';
    }
    return '${units.toStringAsFixed(2)} units';
  }

  /// Parses user meter reading string to centiunits (e.g. "1240.5" -> 124050)
  static int parseReadingToCentiunits(String input) {
    if (input.trim().isEmpty) return 0;
    final cleaned = input.replaceAll(',', '').trim();
    final parts = cleaned.split('.');
    final int whole = int.tryParse(parts[0]) ?? 0;
    int decimal = 0;
    if (parts.length > 1) {
      String dec = parts[1];
      if (dec.length == 1) dec += '0';
      else if (dec.length > 2) dec = dec.substring(0, 2);
      decimal = int.tryParse(dec) ?? 0;
    }
    return (whole * 100) + decimal;
  }

  /// Converts centiunits to readable string for editing
  static String centiunitsToString(int centiunits) {
    if (centiunits % 100 == 0) {
      return (centiunits ~/ 100).toString();
    }
    return (centiunits / 100.0).toStringAsFixed(2);
  }
}
