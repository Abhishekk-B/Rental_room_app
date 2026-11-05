import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/daos/expense_dao.dart';

final expenseDaoProvider = Provider<ExpenseDao>((ref) => ExpenseDao());

final expenseCategoryFilterProvider = StateProvider<String>((ref) => 'ALL');

final expensesListProvider = FutureProvider.autoDispose<List<ExpenseRecord>>((ref) async {
  final category = ref.watch(expenseCategoryFilterProvider);
  final dao = ref.watch(expenseDaoProvider);
  return await dao.getExpenses(category: category);
});
