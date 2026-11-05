class DatabaseTables {
  static const String properties = 'properties';
  static const String rooms = 'rooms';
  static const String tenants = 'tenants';
  static const String tenancies = 'tenancies';
  static const String meters = 'meters';
  static const String meterReadings = 'meter_readings';
  static const String electricityBills = 'electricity_bills';
  static const String electricityAllocations = 'electricity_allocations';
  static const String monthlyBills = 'monthly_bills';
  static const String billLineItems = 'bill_line_items';
  static const String payments = 'payments';
  static const String paymentAllocations = 'payment_allocations';
  static const String expenses = 'expenses';
  static const String auditLogs = 'audit_logs';
  static const String appSettings = 'app_settings';
  static const String advanceLedgerEntries = 'advance_ledger_entries';

  static const List<String> createTableQueries = [
    // 1. Properties
    '''
    CREATE TABLE IF NOT EXISTS $properties (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      address TEXT NOT NULL,
      electricity_billing_type TEXT NOT NULL DEFAULT 'PROPORTIONAL',
      default_electricity_rate_paise INTEGER NOT NULL DEFAULT 850,
      created_at_epoch INTEGER NOT NULL
    );
    ''',

    // 2. Rooms
    '''
    CREATE TABLE IF NOT EXISTS $rooms (
      id TEXT PRIMARY KEY,
      property_id TEXT NOT NULL,
      room_number TEXT NOT NULL UNIQUE,
      description TEXT,
      default_rent_paise INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      notes TEXT,
      created_at_epoch INTEGER NOT NULL,
      FOREIGN KEY (property_id) REFERENCES $properties (id) ON DELETE CASCADE
    );
    ''',

    // 3. Tenants
    '''
    CREATE TABLE IF NOT EXISTS $tenants (
      id TEXT PRIMARY KEY,
      full_name TEXT NOT NULL,
      phone_number TEXT NOT NULL,
      email TEXT,
      permanent_address TEXT,
      emergency_contact TEXT,
      id_proof_type TEXT,
      id_proof_number TEXT,
      notes TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at_epoch INTEGER NOT NULL
    );
    ''',

    // 4. Tenancies (Leases)
    '''
    CREATE TABLE IF NOT EXISTS $tenancies (
      id TEXT PRIMARY KEY,
      tenant_id TEXT NOT NULL,
      room_id TEXT NOT NULL,
      move_in_date_epoch INTEGER NOT NULL,
      move_out_date_epoch INTEGER,
      agreed_rent_paise INTEGER NOT NULL,
      security_deposit_paise INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'ACTIVE', -- 'ACTIVE', 'TERMINATED'
      created_at_epoch INTEGER NOT NULL,
      FOREIGN KEY (tenant_id) REFERENCES $tenants (id),
      FOREIGN KEY (room_id) REFERENCES $rooms (id)
    );
    ''',

    // 5. Sub-meters
    '''
    CREATE TABLE IF NOT EXISTS $meters (
      id TEXT PRIMARY KEY,
      room_id TEXT NOT NULL UNIQUE,
      meter_number TEXT NOT NULL UNIQUE,
      initial_reading_centiunits INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at_epoch INTEGER NOT NULL,
      FOREIGN KEY (room_id) REFERENCES $rooms (id)
    );
    ''',

    // 6. Meter Readings
    '''
    CREATE TABLE IF NOT EXISTS $meterReadings (
      id TEXT PRIMARY KEY,
      meter_id TEXT NOT NULL,
      billing_month INTEGER NOT NULL,
      billing_year INTEGER NOT NULL,
      reading_date_epoch INTEGER NOT NULL,
      previous_reading_centiunits INTEGER NOT NULL,
      current_reading_centiunits INTEGER NOT NULL,
      units_consumed_centiunits INTEGER NOT NULL,
      is_reset INTEGER NOT NULL DEFAULT 0,
      photo_path TEXT,
      notes TEXT,
      created_at_epoch INTEGER NOT NULL,
      UNIQUE(meter_id, billing_month, billing_year),
      FOREIGN KEY (meter_id) REFERENCES $meters (id)
    );
    ''',

    // 7. Electricity Bills (Master Bill received from Utility)
    '''
    CREATE TABLE IF NOT EXISTS $electricityBills (
      id TEXT PRIMARY KEY,
      property_id TEXT NOT NULL,
      billing_month INTEGER NOT NULL,
      billing_year INTEGER NOT NULL,
      total_amount_paise INTEGER NOT NULL,
      fixed_charges_paise INTEGER NOT NULL DEFAULT 0,
      common_area_charges_paise INTEGER NOT NULL DEFAULT 0,
      common_charge_allocation_rule TEXT NOT NULL DEFAULT 'EQUAL',
      is_allocated INTEGER NOT NULL DEFAULT 0,
      bill_date_epoch INTEGER NOT NULL,
      created_at_epoch INTEGER NOT NULL,
      UNIQUE(property_id, billing_month, billing_year),
      FOREIGN KEY (property_id) REFERENCES $properties (id)
    );
    ''',

    // 8. Electricity Allocations
    '''
    CREATE TABLE IF NOT EXISTS $electricityAllocations (
      id TEXT PRIMARY KEY,
      electricity_bill_id TEXT NOT NULL,
      room_id TEXT NOT NULL,
      units_consumed_centiunits INTEGER NOT NULL,
      allocated_amount_paise INTEGER NOT NULL,
      created_at_epoch INTEGER NOT NULL,
      UNIQUE(electricity_bill_id, room_id),
      FOREIGN KEY (electricity_bill_id) REFERENCES $electricityBills (id) ON DELETE CASCADE,
      FOREIGN KEY (room_id) REFERENCES $rooms (id)
    );
    ''',

    // 9. Monthly Bills with Independent Rent & Electricity Advance Deductions
    '''
    CREATE TABLE IF NOT EXISTS $monthlyBills (
      id TEXT PRIMARY KEY,
      tenancy_id TEXT NOT NULL,
      bill_number TEXT NOT NULL UNIQUE,
      billing_month INTEGER NOT NULL,
      billing_year INTEGER NOT NULL,
      bill_date_epoch INTEGER NOT NULL,
      due_date_epoch INTEGER NOT NULL,
      rent_amount_paise INTEGER NOT NULL,
      rent_advance_applied_paise INTEGER NOT NULL DEFAULT 0,
      outstanding_rent_paise INTEGER NOT NULL DEFAULT 0,
      electricity_units_centiunits INTEGER NOT NULL DEFAULT 0,
      electricity_amount_paise INTEGER NOT NULL DEFAULT 0,
      electricity_advance_applied_paise INTEGER NOT NULL DEFAULT 0,
      outstanding_electricity_paise INTEGER NOT NULL DEFAULT 0,
      additional_charges_paise INTEGER NOT NULL DEFAULT 0,
      previous_balance_paise INTEGER NOT NULL DEFAULT 0,
      total_due_paise INTEGER NOT NULL,
      net_amount_due_paise INTEGER NOT NULL DEFAULT 0,
      amount_paid_paise INTEGER NOT NULL DEFAULT 0,
      remaining_balance_paise INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'UNPAID', -- 'UNPAID', 'PARTIALLY_PAID', 'PAID', 'OVERDUE'
      notes TEXT,
      created_at_epoch INTEGER NOT NULL,
      UNIQUE(tenancy_id, billing_month, billing_year),
      FOREIGN KEY (tenancy_id) REFERENCES $tenancies (id)
    );
    ''',

    // 10. Bill Line Items
    '''
    CREATE TABLE IF NOT EXISTS $billLineItems (
      id TEXT PRIMARY KEY,
      monthly_bill_id TEXT NOT NULL,
      description TEXT NOT NULL,
      category TEXT NOT NULL,
      amount_paise INTEGER NOT NULL,
      created_at_epoch INTEGER NOT NULL,
      FOREIGN KEY (monthly_bill_id) REFERENCES $monthlyBills (id) ON DELETE CASCADE
    );
    ''',

    // 11. Payments
    '''
    CREATE TABLE IF NOT EXISTS $payments (
      id TEXT PRIMARY KEY,
      tenancy_id TEXT NOT NULL,
      receipt_number TEXT NOT NULL UNIQUE,
      amount_paise INTEGER NOT NULL,
      payment_date_epoch INTEGER NOT NULL,
      payment_method TEXT NOT NULL, -- 'CASH', 'UPI', 'BANK_TRANSFER', 'CHEQUE', 'OTHER'
      transaction_ref TEXT,
      notes TEXT,
      created_at_epoch INTEGER NOT NULL,
      FOREIGN KEY (tenancy_id) REFERENCES $tenancies (id)
    );
    ''',

    // 12. Payment Allocations
    '''
    CREATE TABLE IF NOT EXISTS $paymentAllocations (
      id TEXT PRIMARY KEY,
      payment_id TEXT NOT NULL,
      monthly_bill_id TEXT NOT NULL,
      amount_allocated_paise INTEGER NOT NULL,
      created_at_epoch INTEGER NOT NULL,
      FOREIGN KEY (payment_id) REFERENCES $payments (id) ON DELETE CASCADE,
      FOREIGN KEY (monthly_bill_id) REFERENCES $monthlyBills (id)
    );
    ''',

    // 13. Property Operating Expenses
    '''
    CREATE TABLE IF NOT EXISTS $expenses (
      id TEXT PRIMARY KEY,
      property_id TEXT NOT NULL,
      category TEXT NOT NULL, -- 'MAINTENANCE', 'REPAIR', 'ELECTRICITY_COMMON', 'PLUMBING', 'CLEANING', 'OTHER'
      amount_paise INTEGER NOT NULL,
      expense_date_epoch INTEGER NOT NULL,
      description TEXT NOT NULL,
      receipt_image_path TEXT,
      created_at_epoch INTEGER NOT NULL,
      FOREIGN KEY (property_id) REFERENCES $properties (id)
    );
    ''',

    // 14. Audit Logs
    '''
    CREATE TABLE IF NOT EXISTS $auditLogs (
      id TEXT PRIMARY KEY,
      action TEXT NOT NULL,
      target_table TEXT NOT NULL,
      target_id TEXT NOT NULL,
      old_values_json TEXT,
      new_values_json TEXT,
      reason TEXT,
      timestamp_epoch INTEGER NOT NULL
    );
    ''',

    // 15. App Settings (Key-Value Store)
    '''
    CREATE TABLE IF NOT EXISTS $appSettings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    ''',

    // 16. Advance & Deposit Ledger Entries (Mandatory Independent Accounts)
    '''
    CREATE TABLE IF NOT EXISTS $advanceLedgerEntries (
      id TEXT PRIMARY KEY,
      tenancy_id TEXT NOT NULL,
      account_type TEXT NOT NULL, -- 'RENT_ADVANCE', 'ELECTRICITY_ADVANCE', 'SECURITY_DEPOSIT'
      transaction_type TEXT NOT NULL, -- 'CREDIT_RECEIVED', 'DEBIT_ADJUSTED', 'DEBIT_REFUNDED', 'TRANSFER', 'REVERSAL'
      amount_paise INTEGER NOT NULL,
      monthly_bill_id TEXT,
      payment_id TEXT,
      description TEXT NOT NULL,
      entry_date_epoch INTEGER NOT NULL,
      created_at_epoch INTEGER NOT NULL,
      FOREIGN KEY (tenancy_id) REFERENCES $tenancies (id),
      FOREIGN KEY (monthly_bill_id) REFERENCES $monthlyBills (id),
      FOREIGN KEY (payment_id) REFERENCES $payments (id)
    );
    ''',
  ];

  static const List<String> createIndexQueries = [
    'CREATE INDEX IF NOT EXISTS idx_rooms_property ON $rooms(property_id);',
    'CREATE INDEX IF NOT EXISTS idx_tenancies_room ON $tenancies(room_id);',
    'CREATE INDEX IF NOT EXISTS idx_tenancies_tenant ON $tenancies(tenant_id);',
    'CREATE INDEX IF NOT EXISTS idx_meter_readings_meter ON $meterReadings(meter_id);',
    'CREATE INDEX IF NOT EXISTS idx_monthly_bills_tenancy ON $monthlyBills(tenancy_id);',
    'CREATE INDEX IF NOT EXISTS idx_monthly_bills_period ON $monthlyBills(billing_year, billing_month);',
    'CREATE INDEX IF NOT EXISTS idx_payments_tenancy ON $payments(tenancy_id);',
    'CREATE INDEX IF NOT EXISTS idx_expenses_property ON $expenses(property_id);',
    'CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON $auditLogs(target_table, target_id);',
    'CREATE INDEX IF NOT EXISTS idx_adv_ledger_tenancy_type ON $advanceLedgerEntries(tenancy_id, account_type);',
    'CREATE INDEX IF NOT EXISTS idx_adv_ledger_bill ON $advanceLedgerEntries(monthly_bill_id);',
  ];
}
