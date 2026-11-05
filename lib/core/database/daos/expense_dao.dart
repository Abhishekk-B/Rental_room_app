import 'package:sqflite/sqflite.dart';
import '../app_database.dart';
import '../tables.dart';

class ExpenseRecord {
  final String id;
  final String propertyId;
  final String category;
  final int amountPaise;
  final int expenseDateEpoch;
  final String description;
  final String? receiptImagePath;

  ExpenseRecord({
    required this.id,
    required this.propertyId,
    required this.category,
    required this.amountPaise,
    required this.expenseDateEpoch,
    required this.description,
    this.receiptImagePath,
  });

  factory ExpenseRecord.fromMap(Map<String, dynamic> map) {
    return ExpenseRecord(
      id: map['id'] as String,
      propertyId: map['property_id'] as String,
      category: map['category'] as String,
      amountPaise: map['amount_paise'] as int,
      expenseDateEpoch: map['expense_date_epoch'] as int,
      description: map['description'] as String,
      receiptImagePath: map['receipt_image_path'] as String?,
    );
  }
}

class ExpenseDao {
  final AppDatabase _dbProvider = AppDatabase.instance;

  Future<List<ExpenseRecord>> getExpenses({
    int? startEpoch,
    int? endEpoch,
    String? category,
  }) async {
    final db = await _dbProvider.database;
    final where = <String>[];
    final args = <dynamic>[];

    if (startEpoch != null) {
      where.add('expense_date_epoch >= ?');
      args.add(startEpoch);
    }
    if (endEpoch != null) {
      where.add('expense_date_epoch <= ?');
      args.add(endEpoch);
    }
    if (category != null && category != 'ALL') {
      where.add('category = ?');
      args.add(category);
    }

    final whereSql = where.isNotEmpty ? 'WHERE ${where.join(' AND ')}' : '';
    final query = '''
      SELECT * FROM ${DatabaseTables.expenses}
      $whereSql
      ORDER BY expense_date_epoch DESC;
    ''';

    final result = await db.rawQuery(query, args);
    return result.map((row) => ExpenseRecord.fromMap(row)).toList();
  }

  Future<void> addExpense({
    required String id,
    required String propertyId,
    required String category,
    required int amountPaise,
    required int expenseDateEpoch,
    required String description,
    String? receiptImagePath,
  }) async {
    final db = await _dbProvider.database;
    await db.insert(DatabaseTables.expenses, {
      'id': id,
      'property_id': propertyId,
      'category': category,
      'amount_paise': amountPaise,
      'expense_date_epoch': expenseDateEpoch,
      'description': description.trim(),
      'receipt_image_path': receiptImagePath,
      'created_at_epoch': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deleteExpense(String id) async {
    final db = await _dbProvider.database;
    await db.delete(
      DatabaseTables.expenses,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
