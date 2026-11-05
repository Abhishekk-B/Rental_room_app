class AppConstants {
  static const int schemaVersion = 2;
  static const String databaseName = 'rentpulse_database.db';
  static const String backupExtension = '.rentpulse.zip';
  static const String appVersion = '1.1.0';

  // Default property seed
  static const String defaultPropertyId = 'prop_default_01';
  static const String defaultPropertyName = 'Main Home (Rental Wing)';
  static const String defaultPropertyAddress = 'Ground Floor & 1st Floor, Main Residence';

  // Defaults
  static const int defaultRatePerUnitPaise = 1000; // ₹10.00 per unit default
  static const int defaultCommonAreaSplit = 3; // 3 rooms
}
