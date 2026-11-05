import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../tables.dart';

class TenantModel {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String? email;
  final String? permanentAddress;
  final String? emergencyContact;
  final String? idProofType;
  final String? idProofNumber;
  final String? notes;
  final bool isActive;
  final int createdAtEpoch;
  final String? activeRoomId;
  final String? activeRoomNumber;
  final String? activeTenancyId;
  final int? agreedRentPaise;

  TenantModel({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.email,
    this.permanentAddress,
    this.emergencyContact,
    this.idProofType,
    this.idProofNumber,
    this.notes,
    required this.isActive,
    required this.createdAtEpoch,
    this.activeRoomId,
    this.activeRoomNumber,
    this.activeTenancyId,
    this.agreedRentPaise,
  });

  factory TenantModel.fromMap(Map<String, dynamic> map) {
    return TenantModel(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      phoneNumber: map['phone_number'] as String,
      email: map['email'] as String?,
      permanentAddress: map['permanent_address'] as String?,
      emergencyContact: map['emergency_contact'] as String?,
      idProofType: map['id_proof_type'] as String?,
      idProofNumber: map['id_proof_number'] as String?,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as int) == 1,
      createdAtEpoch: map['created_at_epoch'] as int,
      activeRoomId: map['active_room_id'] as String?,
      activeRoomNumber: map['active_room_number'] as String?,
      activeTenancyId: map['active_tenancy_id'] as String?,
      agreedRentPaise: map['agreed_rent_paise'] as int?,
    );
  }
}

class TenancyHistoryModel {
  final String id;
  final String tenantId;
  final String roomId;
  final String roomNumber;
  final int moveInDateEpoch;
  final int? moveOutDateEpoch;
  final int agreedRentPaise;
  final int securityDepositPaise;
  final String status;

  TenancyHistoryModel({
    required this.id,
    required this.tenantId,
    required this.roomId,
    required this.roomNumber,
    required this.moveInDateEpoch,
    this.moveOutDateEpoch,
    required this.agreedRentPaise,
    required this.securityDepositPaise,
    required this.status,
  });

  factory TenancyHistoryModel.fromMap(Map<String, dynamic> map) {
    return TenancyHistoryModel(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      roomId: map['room_id'] as String,
      roomNumber: map['room_number'] as String,
      moveInDateEpoch: map['move_in_date_epoch'] as int,
      moveOutDateEpoch: map['move_out_date_epoch'] as int?,
      agreedRentPaise: map['agreed_rent_paise'] as int,
      securityDepositPaise: map['security_deposit_paise'] as int,
      status: map['status'] as String,
    );
  }
}

class TenantDao {
  final AppDatabase _dbProvider = AppDatabase.instance;

  Future<List<TenantModel>> getAllTenants() async {
    final db = await _dbProvider.database;
    final query = '''
      SELECT 
        ten.id,
        ten.full_name,
        ten.phone_number,
        ten.email,
        ten.permanent_address,
        ten.emergency_contact,
        ten.id_proof_type,
        ten.id_proof_number,
        ten.notes,
        ten.is_active,
        ten.created_at_epoch,
        t.id AS active_tenancy_id,
        t.room_id AS active_room_id,
        t.agreed_rent_paise,
        r.room_number AS active_room_number
      FROM ${DatabaseTables.tenants} ten
      LEFT JOIN ${DatabaseTables.tenancies} t 
        ON ten.id = t.tenant_id AND t.status = 'ACTIVE'
      LEFT JOIN ${DatabaseTables.rooms} r 
        ON t.room_id = r.id
      ORDER BY ten.is_active DESC, ten.full_name ASC;
    ''';

    final result = await db.rawQuery(query);
    return result.map((row) => TenantModel.fromMap(row)).toList();
  }

  Future<TenantModel?> getTenantById(String id) async {
    final db = await _dbProvider.database;
    final query = '''
      SELECT 
        ten.id,
        ten.full_name,
        ten.phone_number,
        ten.email,
        ten.permanent_address,
        ten.emergency_contact,
        ten.id_proof_type,
        ten.id_proof_number,
        ten.notes,
        ten.is_active,
        ten.created_at_epoch,
        t.id AS active_tenancy_id,
        t.room_id AS active_room_id,
        t.agreed_rent_paise,
        r.room_number AS active_room_number
      FROM ${DatabaseTables.tenants} ten
      LEFT JOIN ${DatabaseTables.tenancies} t 
        ON ten.id = t.tenant_id AND t.status = 'ACTIVE'
      LEFT JOIN ${DatabaseTables.rooms} r 
        ON t.room_id = r.id
      WHERE ten.id = ?
      LIMIT 1;
    ''';

    final result = await db.rawQuery(query, [id]);
    if (result.isEmpty) return null;
    return TenantModel.fromMap(result.first);
  }

  Future<List<TenancyHistoryModel>> getTenancyHistory(String tenantId) async {
    final db = await _dbProvider.database;
    final query = '''
      SELECT 
        t.id,
        t.tenant_id,
        t.room_id,
        r.room_number,
        t.move_in_date_epoch,
        t.move_out_date_epoch,
        t.agreed_rent_paise,
        t.security_deposit_paise,
        t.status
      FROM ${DatabaseTables.tenancies} t
      JOIN ${DatabaseTables.rooms} r ON t.room_id = r.id
      WHERE t.tenant_id = ?
      ORDER BY t.move_in_date_epoch DESC;
    ''';

    final result = await db.rawQuery(query, [tenantId]);
    return result.map((row) => TenancyHistoryModel.fromMap(row)).toList();
  }

  Future<void> createTenant({
    required String id,
    required String fullName,
    required String phoneNumber,
    String? email,
    String? permanentAddress,
    String? emergencyContact,
    String? idProofType,
    String? idProofNumber,
    String? notes,
  }) async {
    final db = await _dbProvider.database;
    await db.insert(DatabaseTables.tenants, {
      'id': id,
      'full_name': fullName.trim(),
      'phone_number': phoneNumber.trim(),
      'email': email?.trim(),
      'permanent_address': permanentAddress?.trim(),
      'emergency_contact': emergencyContact?.trim(),
      'id_proof_type': idProofType?.trim(),
      'id_proof_number': idProofNumber?.trim(),
      'notes': notes?.trim(),
      'is_active': 1,
      'created_at_epoch': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateTenant({
    required String id,
    required String fullName,
    required String phoneNumber,
    String? email,
    String? permanentAddress,
    String? emergencyContact,
    String? idProofType,
    String? idProofNumber,
    String? notes,
    required bool isActive,
  }) async {
    final db = await _dbProvider.database;
    await db.update(
      DatabaseTables.tenants,
      {
        'full_name': fullName.trim(),
        'phone_number': phoneNumber.trim(),
        'email': email?.trim(),
        'permanent_address': permanentAddress?.trim(),
        'emergency_contact': emergencyContact?.trim(),
        'id_proof_type': idProofType?.trim(),
        'id_proof_number': idProofNumber?.trim(),
        'notes': notes?.trim(),
        'is_active': isActive ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Assigns a tenant to a room (Move-in)
  /// Checks and ensures no active tenancy currently occupies the room
  Future<void> assignTenancy({
    required String tenancyId,
    required String tenantId,
    required String roomId,
    required int moveInDateEpoch,
    required int agreedRentPaise,
    required int securityDepositPaise,
    int billingDueDay = 5,
  }) async {
    final db = await _dbProvider.database;

    await db.transaction((txn) async {
      // 1. Verify room does not have another active tenancy
      final activeCheck = await txn.rawQuery(
        'SELECT id FROM ${DatabaseTables.tenancies} WHERE room_id = ? AND status = ?',
        [roomId, 'ACTIVE'],
      );

      if (activeCheck.isNotEmpty) {
        throw Exception('Cannot assign tenant: This room already has an active occupant.');
      }

      // 2. Also ensure tenant does not have another active tenancy
      final tenantCheck = await txn.rawQuery(
        'SELECT id FROM ${DatabaseTables.tenancies} WHERE tenant_id = ? AND status = ?',
        [tenantId, 'ACTIVE'],
      );

      if (tenantCheck.isNotEmpty) {
        throw Exception('Tenant is already actively assigned to another room.');
      }

      // 3. Insert new tenancy
      await txn.insert(DatabaseTables.tenancies, {
        'id': tenancyId,
        'tenant_id': tenantId,
        'room_id': roomId,
        'move_in_date_epoch': moveInDateEpoch,
        'move_out_date_epoch': null,
        'agreed_rent_paise': agreedRentPaise,
        'security_deposit_paise': securityDepositPaise,
        'billing_due_day': billingDueDay,
        'status': 'ACTIVE',
        'created_at_epoch': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  /// Records move-out / terminates tenancy safely
  Future<void> terminateTenancy({
    required String tenancyId,
    required int moveOutDateEpoch,
  }) async {
    final db = await _dbProvider.database;
    await db.update(
      DatabaseTables.tenancies,
      {
        'move_out_date_epoch': moveOutDateEpoch,
        'status': 'TERMINATED',
      },
      where: 'id = ?',
      whereArgs: [tenancyId],
    );
  }

  /// Safely deletes a tenant and related records
  Future<void> deleteTenant(String tenantId) async {
    final db = await _dbProvider.database;
    await db.transaction((txn) async {
      final tenancies = await txn.query(
        DatabaseTables.tenancies,
        where: 'tenant_id = ?',
        whereArgs: [tenantId],
      );
      for (final t in tenancies) {
        final tid = t['id'] as String;
        await txn.delete(DatabaseTables.advanceLedgerEntries, where: 'tenancy_id = ?', whereArgs: [tid]);
        final payments = await txn.query(DatabaseTables.payments, where: 'tenancy_id = ?', whereArgs: [tid]);
        for (final p in payments) {
          await txn.delete(DatabaseTables.paymentAllocations, where: 'payment_id = ?', whereArgs: [p['id']]);
        }
        await txn.delete(DatabaseTables.payments, where: 'tenancy_id = ?', whereArgs: [tid]);
        final bills = await txn.query(DatabaseTables.monthlyBills, where: 'tenancy_id = ?', whereArgs: [tid]);
        for (final b in bills) {
          await txn.delete(DatabaseTables.billLineItems, where: 'monthly_bill_id = ?', whereArgs: [b['id']]);
        }
        await txn.delete(DatabaseTables.monthlyBills, where: 'tenancy_id = ?', whereArgs: [tid]);
        await txn.delete(DatabaseTables.tenancies, where: 'id = ?', whereArgs: [tid]);
      }
      await txn.delete(DatabaseTables.tenants, where: 'id = ?', whereArgs: [tenantId]);
    });
  }
}
