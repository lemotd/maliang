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
  housing('住房', Icons.home_outlined),
  utilities('缴费', Icons.receipt_long_outlined),
  social('人情', Icons.card_giftcard_outlined),
  education('教育', Icons.school_outlined),
  medical('医疗', Icons.local_hospital_outlined),
  insurance('保险', Icons.security_outlined),
  pet('宠物', Icons.pets_outlined),
  travel('旅行', Icons.flight_outlined),
  transfer('转账', Icons.swap_horiz_outlined),
  investment('投资', Icons.trending_up_outlined),
  shopping('购物', Icons.shopping_bag_outlined),
  charity('公益', Icons.volunteer_activism_outlined),
  childcare('养娃', Icons.child_care_outlined),
  other('其他', Icons.more_horiz_outlined);

  final String label;
  final IconData icon;

  const BillExpenseCategory(this.label, this.icon);
}

enum BillIncomeCategory {
  salary('工资', Icons.work_outline),
  bonus('奖金', Icons.card_giftcard_outlined),
  partTime('兼职', Icons.schedule_outlined),
  business('生意', Icons.store_outlined),
  investment('理财', Icons.trending_up_outlined),
  transfer('转账', Icons.swap_horiz_outlined),
  living('生活费', Icons.account_balance_wallet_outlined),
  other('其他', Icons.more_horiz_outlined);

  final String label;
  final IconData icon;

  const BillIncomeCategory(this.label, this.icon);
}
