import 'package:flutter/material.dart';

enum BillExpenseCategory {
  dining('餐饮', Icons.restaurant_outlined),
  snacks('零食', Icons.cookie_outlined),
  transport('交通', Icons.directions_bus_outlined),
  daily('日用', Icons.shopping_basket_outlined),
  entertainment('娱乐', Icons.sports_esports_outlined),
  sports('运动', Icons.fitness_center_outlined),
  clothing('服饰', Icons.checkroom_outlined),
  home('家居', Icons.chair_outlined),
  communication('通讯', Icons.phone_outlined),
  tobacco('烟酒', Icons.smoking_rooms_outlined),
  medical('医疗', Icons.local_hospital_outlined),
  education('教育', Icons.school_outlined),
  gift('礼物', Icons.card_giftcard_outlined),
  pet('宠物', Icons.pets_outlined),
  beauty('美容', Icons.face_retouching_natural),
  repair('维修', Icons.build_outlined),
  travel('旅行', Icons.flight_outlined),
  car('汽车', Icons.directions_car_outlined),
  insurance('保险', Icons.security_outlined),
  tax('税费', Icons.receipt_long_outlined),
  investment('投资', Icons.trending_up_outlined),
  transfer('转账', Icons.swap_horiz_outlined),
  other('其他', Icons.more_horiz_outlined);

  final String label;
  final IconData icon;

  const BillExpenseCategory(this.label, this.icon);

  String get name {
    switch (this) {
      case BillExpenseCategory.dining:
        return 'dining';
      case BillExpenseCategory.snacks:
        return 'snacks';
      case BillExpenseCategory.transport:
        return 'transport';
      case BillExpenseCategory.daily:
        return 'daily';
      case BillExpenseCategory.entertainment:
        return 'entertainment';
      case BillExpenseCategory.sports:
        return 'sports';
      case BillExpenseCategory.clothing:
        return 'clothing';
      case BillExpenseCategory.home:
        return 'home';
      case BillExpenseCategory.communication:
        return 'communication';
      case BillExpenseCategory.tobacco:
        return 'tobacco';
      case BillExpenseCategory.medical:
        return 'medical';
      case BillExpenseCategory.education:
        return 'education';
      case BillExpenseCategory.gift:
        return 'gift';
      case BillExpenseCategory.pet:
        return 'pet';
      case BillExpenseCategory.beauty:
        return 'beauty';
      case BillExpenseCategory.repair:
        return 'repair';
      case BillExpenseCategory.travel:
        return 'travel';
      case BillExpenseCategory.car:
        return 'car';
      case BillExpenseCategory.insurance:
        return 'insurance';
      case BillExpenseCategory.tax:
        return 'tax';
      case BillExpenseCategory.investment:
        return 'investment';
      case BillExpenseCategory.transfer:
        return 'transfer';
      case BillExpenseCategory.other:
        return 'other_expense';
    }
  }

  static BillExpenseCategory? fromName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final category in BillExpenseCategory.values) {
      if (category.name.toLowerCase() == normalized ||
          category.label == name.trim()) {
        return category;
      }
    }
    // 模糊匹配：AI可能返回包含关键词的变体
    for (final category in BillExpenseCategory.values) {
      if (normalized.contains(category.name.toLowerCase()) ||
          category.name.toLowerCase().contains(normalized)) {
        return category;
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'label': label, 'icon': icon};
  }

  static List<Map<String, dynamic>> get allMaps =>
      values.map((e) => e.toMap()).toList();

  static String get aiPromptList =>
      values.map((e) => '${e.name}(${e.label})').join('、');
}

enum BillIncomeCategory {
  salary('工资', Icons.work_outline),
  bonus('奖金', Icons.card_giftcard_outlined),
  investment('投资', Icons.trending_up_outlined),
  partTime('兼职', Icons.access_time_outlined),
  gift('红包', Icons.redeem_outlined),
  refund('退款', Icons.assignment_return_outlined),
  transfer('转账', Icons.swap_horiz_outlined),
  other('其他', Icons.more_horiz_outlined);

  final String label;
  final IconData icon;

  const BillIncomeCategory(this.label, this.icon);

  String get name {
    switch (this) {
      case BillIncomeCategory.salary:
        return 'salary';
      case BillIncomeCategory.bonus:
        return 'bonus';
      case BillIncomeCategory.investment:
        return 'investment_income';
      case BillIncomeCategory.partTime:
        return 'part_time';
      case BillIncomeCategory.gift:
        return 'gift_income';
      case BillIncomeCategory.refund:
        return 'refund';
      case BillIncomeCategory.transfer:
        return 'transfer_income';
      case BillIncomeCategory.other:
        return 'other_income';
    }
  }

  static BillIncomeCategory? fromName(String name) {
    final normalized = name.trim().toLowerCase();
    for (final category in BillIncomeCategory.values) {
      if (category.name.toLowerCase() == normalized ||
          category.label == name.trim()) {
        return category;
      }
    }
    // 模糊匹配：AI可能返回包含关键词的变体
    for (final category in BillIncomeCategory.values) {
      if (normalized.contains(category.name.toLowerCase()) ||
          category.name.toLowerCase().contains(normalized)) {
        return category;
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'label': label, 'icon': icon};
  }

  static List<Map<String, dynamic>> get allMaps =>
      values.map((e) => e.toMap()).toList();

  static String get aiPromptList =>
      values.map((e) => '${e.name}(${e.label})').join('、');
}
