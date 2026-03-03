import 'package:flutter/material.dart';

enum MemoryCategory {
  pickupCode('取餐码', Color(0xFFFF9500)),
  packageCode('取件码', Color(0xFF34C759)),
  bill('账单', Color(0xFF007AFF)),
  note('随手记', Color(0xFF8E8E93));

  final String label;
  final Color color;
  const MemoryCategory(this.label, this.color);
}

class MemoryItem {
  final String id;
  final String title;
  final MemoryCategory category;
  final String? imagePath;
  final String? thumbnailPath;
  final DateTime createdAt;
  final String? rawContent;
  final bool isCompleted;

  // 详细信息字段
  final String? shopName;
  final String? pickupCode;
  final String? dishName;
  final String? expressCompany;
  final String? pickupAddress;
  final String? productType;
  final String? trackingNumber;
  final String? amount;
  final String? paymentMethod;
  final String? merchantName;

  MemoryItem({
    required this.id,
    required this.title,
    required this.category,
    this.imagePath,
    this.thumbnailPath,
    required this.createdAt,
    this.rawContent,
    this.isCompleted = false,
    this.shopName,
    this.pickupCode,
    this.dishName,
    this.expressCompany,
    this.pickupAddress,
    this.productType,
    this.trackingNumber,
    this.amount,
    this.paymentMethod,
    this.merchantName,
  });

  MemoryItem copyWith({
    String? id,
    String? title,
    MemoryCategory? category,
    String? imagePath,
    String? thumbnailPath,
    DateTime? createdAt,
    String? rawContent,
    bool? isCompleted,
    String? shopName,
    String? pickupCode,
    String? dishName,
    String? expressCompany,
    String? pickupAddress,
    String? productType,
    String? trackingNumber,
    String? amount,
    String? paymentMethod,
    String? merchantName,
  }) {
    return MemoryItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      rawContent: rawContent ?? this.rawContent,
      isCompleted: isCompleted ?? this.isCompleted,
      shopName: shopName ?? this.shopName,
      pickupCode: pickupCode ?? this.pickupCode,
      dishName: dishName ?? this.dishName,
      expressCompany: expressCompany ?? this.expressCompany,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      productType: productType ?? this.productType,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      merchantName: merchantName ?? this.merchantName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category.name,
      'imagePath': imagePath,
      'thumbnailPath': thumbnailPath,
      'createdAt': createdAt.toIso8601String(),
      'rawContent': rawContent,
      'isCompleted': isCompleted,
      'shopName': shopName,
      'pickupCode': pickupCode,
      'dishName': dishName,
      'expressCompany': expressCompany,
      'pickupAddress': pickupAddress,
      'productType': productType,
      'trackingNumber': trackingNumber,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'merchantName': merchantName,
    };
  }

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: json['id'] as String,
      title: json['title'] as String,
      category: MemoryCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => MemoryCategory.note,
      ),
      imagePath: json['imagePath'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      rawContent: json['rawContent'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
      shopName: json['shopName'] as String?,
      pickupCode: json['pickupCode'] as String?,
      dishName: json['dishName'] as String?,
      expressCompany: json['expressCompany'] as String?,
      pickupAddress: json['pickupAddress'] as String?,
      productType: json['productType'] as String?,
      trackingNumber: json['trackingNumber'] as String?,
      amount: json['amount'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      merchantName: json['merchantName'] as String?,
    );
  }

  List<String> getDetailInfo() {
    final details = <String>[];

    switch (category) {
      case MemoryCategory.pickupCode:
        if (shopName != null && shopName!.isNotEmpty) {
          // 检查标题是否已包含店铺名
          if (!title.contains(shopName!)) {
            details.add(shopName!);
          }
        }
        if (pickupCode != null && pickupCode!.isNotEmpty) {
          // 检查标题是否已包含取餐码
          if (!title.contains(pickupCode!)) {
            details.add(pickupCode!);
          }
        }
        if (dishName != null && dishName!.isNotEmpty) {
          // 检查标题是否已包含餐品名称
          if (!title.contains(dishName!)) {
            details.add(dishName!);
          }
        }
        break;
      case MemoryCategory.packageCode:
        if (expressCompany != null && expressCompany!.isNotEmpty) {
          details.add(expressCompany!);
        }
        if (pickupCode != null && pickupCode!.isNotEmpty) {
          // 检查标题是否已包含取件码
          if (!title.contains(pickupCode!)) {
            details.add(pickupCode!);
          }
        }
        if (pickupAddress != null && pickupAddress!.isNotEmpty) {
          details.add(pickupAddress!);
        }
        if (productType != null && productType!.isNotEmpty) {
          details.add(productType!);
        }
        if (trackingNumber != null && trackingNumber!.isNotEmpty) {
          details.add(trackingNumber!);
        }
        break;
      case MemoryCategory.bill:
        if (amount != null && amount!.isNotEmpty) {
          // 检查标题是否已包含金额
          if (!title.contains(amount!)) {
            details.add(amount!);
          }
        }
        if (paymentMethod != null && paymentMethod!.isNotEmpty) {
          details.add(paymentMethod!);
        }
        if (merchantName != null && merchantName!.isNotEmpty) {
          details.add(merchantName!);
        }
        break;
      case MemoryCategory.note:
        break;
    }

    return details;
  }
}
