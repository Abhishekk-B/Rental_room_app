import 'package:intl/intl.dart';

class DateHelper {
  static final DateFormat _dateFormat = DateFormat('dd-MM-yyyy');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
  static final DateFormat _shortMonthYearFormat = DateFormat('MMM yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd-MM-yyyy hh:mm a');

  static const List<String> monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  /// Returns full month name from 1-12
  static String getMonthName(int month) {
    if (month >= 1 && month <= 12) {
      return monthNames[month - 1];
    }
    return '';
  }

  /// Formats epoch milliseconds to DD-MM-YYYY
  static String formatEpoch(int epochMillis) {
    if (epochMillis <= 0) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMillis);
    return _dateFormat.format(dt);
  }

  /// Formats DateTime to DD-MM-YYYY
  static String formatDate(DateTime dt) {
    return _dateFormat.format(dt);
  }

  /// Formats Month (1-12) and Year (e.g. 11, 2026 -> "November 2026")
  static String formatBillingPeriod(int month, int year) {
    final dt = DateTime(year, month, 1);
    return _monthYearFormat.format(dt);
  }

  /// Formats Month (1-12) and Year (e.g. 11, 2026 -> "Nov 2026")
  static String formatShortBillingPeriod(int month, int year) {
    final dt = DateTime(year, month, 1);
    return _shortMonthYearFormat.format(dt);
  }

  /// Formats epoch to full date and time string
  static String formatDateTimeEpoch(int epochMillis) {
    if (epochMillis <= 0) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMillis);
    return _dateTimeFormat.format(dt);
  }

  /// Parses DD-MM-YYYY string to DateTime
  static DateTime? parseDate(String input) {
    try {
      return _dateFormat.parseStrict(input.trim());
    } catch (_) {
      return null;
    }
  }

  /// Returns current epoch timestamp in milliseconds
  static int nowEpoch() => DateTime.now().millisecondsSinceEpoch;

  /// Returns epoch for the start of the specified month
  static int startOfMonthEpoch(int month, int year) {
    return DateTime(year, month, 1).millisecondsSinceEpoch;
  }

  /// Returns due date (e.g. 7th or 10th of the month)
  static int dueDateEpoch(int month, int year, {int day = 7}) {
    return DateTime(year, month, day).millisecondsSinceEpoch;
  }
}
