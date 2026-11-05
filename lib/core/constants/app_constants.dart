class AppConstants {
  static const int schemaVersion = 1;
  static const String databaseName = 'rentpulse_database.db';
  static const String backupExtension = '.rentpulse.zip';
  static const String appVersion = '1.0.0';

  // Default property seed
  static const String defaultPropertyId = 'prop_default_01';
  static const String defaultPropertyName = 'Main Home (Rental Wing)';
  static const String defaultPropertyAddress = 'Ground Floor & 1st Floor, Main Residence';

  // Defaults
  static const int defaultRatePerUnitPaise = 850; // ₹8.50 per unit
  static const int defaultCommonAreaSplit = 3; // 3 rooms
}
