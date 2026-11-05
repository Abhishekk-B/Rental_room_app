# RentPulse — Offline Rental Room Management Android App

**RentPulse** is a 100% offline, local-first Android application designed specifically for homeowners renting out rooms in their house. Built with **Flutter**, **Material Design 3**, and **SQLite**, it operates completely on-device in **Airplane Mode** without any backend server, Django, PostgreSQL, cloud services, or external network calls.

---

## Key Highlights

- **100% Offline & Airplane-Mode Capable:** Zero backend dependencies, no cloud subscriptions, no user registration, no tracking.
- **Independent Advance Accounts (Strict Separation):** Separate Rent Advance, Electricity Advance, and Security Deposit accounts for every tenant with an immutable SQLite transaction ledger. Rent advances apply strictly against rent, and electricity advances apply strictly against electricity.
- **Zero Financial Discrepancies:** All monetary amounts are handled in **integer minor units (Paise: $1\text{ INR} = 100\text{ Paise}$)** to eliminate IEEE-754 floating-point inaccuracies.
- **Exact Penny-Reconciliation Electricity Engine:** Supports both fixed per-unit sub-metering and proportional master-bill splitting across rooms. Fractional paise differences are automatically absorbed by the highest consumer, ensuring the allocated sum matches the master electricity bill down to the exact paise.
- **Normalized SQLite Persistence:** 15 relational tables with constraints, indexes, foreign keys, and audit logging.
- **Local PDF Generation & Sharing:** Produces professional, printable PDF rent invoices and payment receipts with customizable owner branding and UPI details, shared directly via the Android native share sheet.
- **Complete ZIP Backup & Restore:** Backs up all database records and attachment photos into a `.rentpulse.zip` file with manifest verification and rollback safety.
- **Local App Security:** Optional 4-digit PIN lock using salted SHA-256 local storage.

---

## System Architecture

```
rental_room_app/
├── android/            # Android Gradle wrapper & native configurations
├── lib/
│   ├── core/
│   │   ├── constants/  # Colors, Indian Rupee formatting, App strings
│   │   ├── database/   # SQLite tables, AppDatabase, and DAOs
│   │   │   ├── tables.dart
│   │   │   ├── app_database.dart
│   │   │   └── daos/   # RoomDao, TenantDao, ElectricityDao, BillingDao, PaymentDao, ExpenseDao, ReportDao
│   │   ├── services/   # Local PDF generation, ZIP Backup/Restore, Security
│   │   ├── utils/      # CurrencyHelper (Paise), DateHelper
│   │   └── widgets/    # StatCard, StatusBadge, ConfirmDialog, EmptyState
│   ├── features/
│   │   ├── auth/       # 4-Digit Local PIN Lock
│   │   ├── dashboard/  # Monthly overview, financial metrics, upcoming dues
│   │   ├── rooms/      # Room management, occupancy status, sub-meters
│   │   ├── tenants/    # Tenant registry, move-in/move-out, lease history
│   │   ├── electricity/# Sub-meter readings, master bill proportional split
│   │   ├── billing/    # Monthly bill generation, line items, previous dues
│   │   ├── payments/   # Payment receipts, auto-allocation to oldest bills
│   │   ├── expenses/   # Property maintenance, repairs, and common charges
│   │   ├── reports/    # Yearly income vs expenses, collection rates
│   │   └── settings/   # Owner profile, UPI ID, PIN, ZIP Backup & Restore
│   ├── routing/        # GoRouter navigation & bottom navigation scaffold
│   └── main.dart       # App entry point & Material 3 theme configuration
├── test/
│   ├── unit_calculations_test.dart  # 10/10 passing unit tests for electricity & billing
│   ├── backup_manifest_test.dart    # Backup manifest & verification tests
│   └── widget_test.dart             # UI widget tests
├── pubspec.yaml
└── PROJECT_CHECKLIST.md
```

---

## Database Architecture (16 SQLite Tables)

1. `properties`: Property master details and default electricity billing rate.
2. `rooms`: Rental rooms with default rent and occupancy state (seeded with Room 101, 102, 103).
3. `tenants`: Tenant contact info, emergency contact, ID document reference, and notes.
4. `tenancies`: Historical and active leases linking tenants to rooms (prevents overlapping tenancies).
5. `meters`: Room electricity sub-meter identifiers and initial readings.
6. `meter_readings`: Monthly sub-meter readings with monotonic validation and rollover flags.
7. `electricity_bills`: Master utility electricity bills received for the house.
8. `electricity_allocations`: Room-wise consumption proportions and allocated amounts.
9. `monthly_bills`: Frozen snapshot invoices for each room and billing period.
10. `bill_line_items`: Itemized charges breakdown (Rent, Electricity, Maintenance, Water, etc.).
11. `payments`: Payment records (Cash, UPI, Bank Transfer, Cheque).
12. `payment_allocations`: Traces payments allocated to specific bills (oldest dues cleared first).
13. `expenses`: Operating expenses (Maintenance, Repairs, Common Electricity, Cleaning).
14. `audit_logs`: Audit trail for financial adjustments and reading revisions.
15. `app_settings`: Key-value configuration for owner profile, default due days, and PIN settings.
16. `advance_ledger_entries`: Strict double-entry ledger for Rent Advance, Electricity Advance, and Security Deposit accounts with immutable transaction history.

---

## Electricity Calculation & Reconciliation Logic

### 1. Fixed Rate Sub-metering
$$\text{Units} = \frac{\text{Current Reading} - \text{Previous Reading}}{100}$$
$$\text{Charge (Paise)} = \text{Round}\left(\text{Units} \times \text{RateInPaise}\right)$$

### 2. Proportional Master Bill Allocation (Penny Reconciled)
Given total bill $B$, fixed charges $F$, and common charges $C$:
$$\text{Variable Pool} = B - F - C$$
Each room's base variable share:
$$\text{Base}_i = \left\lfloor \frac{\text{Variable Pool} \times U_i}{\sum U_k} \right\rfloor$$
Common area share per room:
$$\text{Common}_i = \left\lfloor \frac{F + C}{N} \right\rfloor$$
**Paise Adjustment:**  
Any leftover difference $(B - \sum (\text{Base}_i + \text{Common}_i))$ is deterministically applied to the room with the highest consumption. This mathematically guarantees:
$$\sum_{i=1}^N \text{Allocated}_i \equiv B\text{ (Exact to the paise)}$$

---

## How to Run & Build

### Prerequisites
- Flutter SDK (v3.10.0 or later)
- Android Studio or VS Code with Flutter extension
- Android Device (Android 5.0 / API 21+) or Emulator

### 1. Run in Development Mode
```bash
cd rental_room_app
flutter pub get
flutter run
```

### 2. Run Automated Tests
```bash
# Unit calculation and financial tests
flutter test test/unit_calculations_test.dart

# Independent rent & electricity advance accounts test
flutter test test/advance_accounts_test.dart

# Backup manifest integrity tests
flutter test test/backup_manifest_test.dart

# Widget tests
flutter test test/widget_test.dart
```

### 3. Build Android APKs

#### Debug APK (for quick device testing)
```bash
flutter build apk --debug
```
*Output location:* `build/app/outputs/flutter-apk/app-debug.apk`

#### Release APK (for production installation)
```bash
flutter build apk --release
```
*Output location:* `build/app/outputs/flutter-apk/app-release.apk`

---

## Backup & Restore Procedures

### Creating a Backup
1. Navigate to **More** $\rightarrow$ **Settings & Backup** $\rightarrow$ **Backup & Restore Data**.
2. Tap **Create & Share Backup ZIP**.
3. RentPulse will bundle the SQLite database JSON, manifest, and all photo attachments into a single `.rentpulse.zip` file.
4. The Android Share Sheet will appear. You can save it to **Google Drive**, **Files/Downloads**, **SD Card**, or send it to your email or WhatsApp.

### Restoring a Backup
1. In the **Backup & Restore** screen, tap **Select Backup ZIP to Restore**.
2. RentPulse prompts for confirmation to prevent accidental overwrites.
3. Select your `.rentpulse.zip` file using the Android file picker.
4. The system validates the `manifest.json` and schema version, executes an atomic database restore, and updates all records immediately.
