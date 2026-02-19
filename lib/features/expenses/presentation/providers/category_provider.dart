import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moneii_manager/core/constants.dart';
import 'package:moneii_manager/features/auth/presentation/providers/auth_provider.dart';
import 'package:moneii_manager/features/expenses/domain/entities/category.dart';

final categoriesProvider = FutureProvider<List<ExpenseCategory>>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  try {
    final data = await client
        .from('categories')
        .select('id, name, icon, color, parent_id')
        .order('id');

    final rows = (data as List)
        .map((json) => ExpenseCategory.fromJson(json as Map<String, dynamic>))
        .toList();

    if (rows.isNotEmpty) return rows;
  } catch (_) {
    // Fallback for local development before schema seed.
  }

  var id = 1;
  final fallback = <ExpenseCategory>[];
  for (final category in AppCategories.all) {
    final parentId = id++;
    fallback.add(ExpenseCategory(id: parentId, name: category.name));
    for (final subcategory in category.subcategories) {
      fallback.add(
        ExpenseCategory(id: id++, name: subcategory, parentId: parentId),
      );
    }
  }

  return fallback;
});

final categoryTreeProvider = Provider<List<CategoryGroup>>((ref) {
  final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
  final parents =
      categories.where((category) => category.parentId == null).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  return parents.map((parent) {
    final children =
        categories.where((category) => category.parentId == parent.id).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return CategoryGroup(parent: parent, children: children);
  }).toList();
});

final categoryByIdProvider = Provider<Map<int, ExpenseCategory>>((ref) {
  final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
  return {for (final category in categories) category.id: category};
});
