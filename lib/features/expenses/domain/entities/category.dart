import 'package:flutter/material.dart';
import 'package:moneii_manager/config/theme.dart';

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.parentId,
  });

  final int id;
  final String name;
  final String? icon;
  final String? color;
  final int? parentId;

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      parentId: json['parent_id'] as int?,
    );
  }

  IconData get iconData {
    switch (icon) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'receipt':
        return Icons.receipt_long_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'flight':
        return Icons.flight_rounded;
      case 'person':
        return Icons.person_rounded;
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color get displayColor {
    if (color == null) return AppColors.categoryOther;
    final value = color!.replaceAll('#', '');
    if (value.length == 6) {
      try {
        return Color(int.parse('FF$value', radix: 16));
      } catch (_) {
        return AppColors.categoryOther;
      }
    }
    return AppColors.categoryOther;
  }
}

class CategoryGroup {
  const CategoryGroup({required this.parent, required this.children});

  final ExpenseCategory parent;
  final List<ExpenseCategory> children;
}
