# RentPulse - Offline Rental Room Management App
## Implementation Checklist & Status

### 1. Architecture & Local Persistence
- [x] Completely removed all server/Django/backend dependencies
- [x] Designed 100% offline, local-first architecture for Android (airplane mode capable)
- [x] Created normalized SQLite database schema with 16 tables:
  - `properties`, `rooms`, `tenants`, `tenancies`, `meters`, `meter_readings`
  - `electricity_bills`, `electricity_allocations`, `monthly_bills`, `bill_line_items`
  - `payments`, `payment_allocations`, `expenses`, `audit_logs`, `app_settings`
  - `advance_ledger_entries` (Mandatory independent accounts ledger)
- [x] Strict integer paise currency representation (`int64`, 1 INR = 100 paise) avoiding floating-point financial bugs
- [x] Automatic database seeding: 1 Property, 3 Rental Rooms, 3 Sub-meters, 2 Sample Tenants with active tenancies, and default configuration

### 2. Independent Advance Accounts & Strict Separation
- [x] Independent Rent Advance Account: Record advance payments specifically for rent, maintain available balance, apply only against rent charges
- [x] Independent Electricity Advance Account: Record advance payments specifically for electricity, maintain available balance, apply only against electricity charges
- [x] Strict Separation Rules: Rent advance NEVER automatically pays electricity bills; Electricity advance NEVER automatically pays rent bills
- [x] Separate Security Deposit Account: Tracked independently from both advance accounts
- [x] Authorized Cross-Account Transfer: Mandatory audit log and explicit reason required for manual transfers
- [x] Immutable ledger entries (`advance_ledger_entries`) supporting credits, debits, adjustments, refunds, and transfers

### 3. Domain & Calculation Engines
- [x] `ElectricityCalculator`: Pure Dart engine for fixed-rate and proportional master bill allocation
- [x] Exact Penny Reconciliation: Fractional paise adjustments absorbed by highest consumer, ensuring zero financial discrepancy
- [x] Monotonic reading validation ($\text{Current} \ge \text{Previous}$) with explicit rollover/reset override
- [x] Safe zero-total-consumption handling
- [x] `BillingEngine`: Monthly bill calculation with independent rent and electricity advance adjustments
- [x] Calculates outstanding rent and outstanding electricity separately
- [x] Automated unit test suite passing 14/14 tests in containerized test runner (10 domain tests + 4 advance account tests)

### 4. Room & Tenant Management
- [x] Room list with real-time occupancy badges, default rents, and sub-meter identifiers
- [x] Add and edit room forms with validation
- [x] Room details with active occupant, lease terms, and sub-meter stats
- [x] Tenant directory with active vs historical indicators
- [x] Move-in assignment with validation preventing multiple active occupants in a room
- [x] Move-out termination preserving all past bills and payment histories
- [x] Tenant profile showing Rent Advance card, Electricity Advance card, Security Deposit card, and outstanding dues breakdown
- [x] Tenant advance transaction ledger history view (`/tenants/:id/advances`)

### 5. Electricity Metering & Master Bill Split
- [x] Meter reading entry with automatic previous reading lookup and live unit consumption display
- [x] Optional meter photo attachment saved locally
- [x] Meter reset/rollover switch
- [x] Proportional bill allocation screen with real-time preview table
- [x] Master bill saving with room-level allocations

### 6. Monthly Rent Billing & Invoicing
- [x] Bill generation screen with available Rent Advance & Electricity Advance lookup
- [x] Independent advance deduction inputs with "Apply Max" quick buttons
- [x] Status tracking: `UNPAID`, `PARTIALLY_PAID`, `PAID`, `OVERDUE`
- [x] Bill detail view with itemized charges breakdown (Rent, Advance Deductions, Electricity, Net Due)
- [x] Local PDF generation for bills (`PdfInvoiceService`)
- [x] Share invoice PDF via Android native share sheet

### 7. Payment & Expense Management
- [x] Record payment with methods (UPI, Cash, Bank Transfer, Cheque, Other)
- [x] Auto-allocation of payments to the oldest unpaid bills
- [x] Payment receipt PDF generation and sharing
- [x] Expense logging with categories (Maintenance, Repairs, Common Power, Plumbing, Cleaning, Other)
- [x] Receipt attachment storage

### 8. Dashboard, Reports & Settings
- [x] Executive dashboard with billing period selector (Month YYYY)
- [x] 5 Separate Cards:
  1. Total Rent Advance Balance
  2. Total Electricity Advance Balance
  3. Total Security Deposits
  4. Outstanding Rent
  5. Outstanding Electricity
- [x] General stats: Payments received, Total dues pending, Occupancy bar
- [x] Upcoming rent due dates list
- [x] Recent payments list
- [x] Yearly income vs expense reports with net cash flow per month
- [x] Settings screen for owner invoice details, UPI ID, and app version
- [x] Local 4-digit PIN lock security
- [x] Complete standalone ZIP backup and restore with manifest verification and rollback safety

### 9. Testing & Documentation
- [x] Unit calculation tests (`test/unit_calculations_test.dart`)
- [x] Independent advance account tests (`test/advance_accounts_test.dart`)
- [x] Backup manifest integrity tests (`test/backup_manifest_test.dart`)
- [x] Widget tests (`test/widget_test.dart`)
- [x] Production documentation and release build instructions in `README.md`
