import 'package:flutter/material.dart';

enum MemoryCategory {
  pickupCode('取餐码', Color(0xFFFF9500)),
  packageCode('取件码', Color(0xFF34C759)),
  bill('账单', Color(0xFF007AFF)),
  clothing('服饰', Color(0xFFE91E63)),
  note('随手记', Color(0xFF8E8E93));

  final String label;
  final Color color;
  const MemoryCategory(this.label, this.color);
}

class InfoSection {
  final String title;
  final List<InfoItem> items;

  const InfoSection({required this.title, required this.items});

  factory InfoSection.fromJson(Map<String, dynamic> json) {
    return InfoSection(
      title: json['title'] as String? ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => InfoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'title': title, 'items': items.map((e) => e.toJson()).toList()};
  }
}

class InfoItem {
  final String label;
  final String value;

  const InfoItem({required this.label, required this.value});

  factory InfoItem.fromJson(Map<String, dynamic> json) {
    return InfoItem(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'label': label, 'value': value};
  }
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
  final bool? isExpense; // 账单类型：true=支出，false=收入
  final String? billCategory; // 账单分类：支出/收入的具体分类
  final String? note; // 备注
  final String? paymentMethod;
  final String? merchantName;
  final DateTime? billTime; // 账单时间（AI识别的时间）
  final String? summary; // AI生成的账单摘要
  final List<InfoSection> infoSections; // 结构化信息区域

  // 服饰专属字段
  final String? clothingName; // 服饰名称
  final String? clothingType; // 分类（T恤、衬衫等）
  final List<String> clothingColors; // 色系（hex色值列表）
  final List<String> clothingSeasons; // 适用季节
  final String? clothingBrand; // 品牌
  final String? clothingPrice; // 价格
  final String? clothingSize; // 尺码
  final String? clothingPurchaseDate; // 购买日期
  final List<String> customClothingSizes; // 自定义衣服尺码
  final List<String> customShoeSizes; // 自定义鞋子尺码

  // 日程字段
  final String? eventName; // 日程名称
  final DateTime? eventStartTime; // 日程开始时间
  final DateTime? eventEndTime; // 日程结束时间

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
    this.isExpense,
    this.billCategory,
    this.note,
    this.paymentMethod,
    this.merchantName,
    this.billTime,
    this.summary,
    this.infoSections = const [],
    this.clothingName,
    this.clothingType,
    this.clothingColors = const [],
    this.clothingSeasons = const [],
    this.clothingBrand,
    this.clothingPrice,
    this.clothingSize,
    this.clothingPurchaseDate,
    this.customClothingSizes = const [],
    this.customShoeSizes = const [],
    this.eventName,
    this.eventStartTime,
    this.eventEndTime,
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
    bool? isExpense,
    String? billCategory,
    String? note,
    String? paymentMethod,
    String? merchantName,
    DateTime? billTime,
    String? summary,
    List<InfoSection>? infoSections,
    String? clothingName,
    String? clothingType,
    List<String>? clothingColors,
    List<String>? clothingSeasons,
    String? clothingBrand,
    String? clothingPrice,
    String? clothingSize,
    String? clothingPurchaseDate,
    List<String>? customClothingSizes,
    List<String>? customShoeSizes,
    String? eventName,
    DateTime? eventStartTime,
    DateTime? eventEndTime,
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
      isExpense: isExpense ?? this.isExpense,
      billCategory: billCategory ?? this.billCategory,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      merchantName: merchantName ?? this.merchantName,
      billTime: billTime ?? this.billTime,
      summary: summary ?? this.summary,
      infoSections: infoSections ?? this.infoSections,
      clothingName: clothingName ?? this.clothingName,
      clothingType: clothingType ?? this.clothingType,
      clothingColors: clothingColors ?? this.clothingColors,
      clothingSeasons: clothingSeasons ?? this.clothingSeasons,
      clothingBrand: clothingBrand ?? this.clothingBrand,
      clothingPrice: clothingPrice ?? this.clothingPrice,
      clothingSize: clothingSize ?? this.clothingSize,
      clothingPurchaseDate: clothingPurchaseDate ?? this.clothingPurchaseDate,
      customClothingSizes: customClothingSizes ?? this.customClothingSizes,
      customShoeSizes: customShoeSizes ?? this.customShoeSizes,
      eventName: eventName ?? this.eventName,
      eventStartTime: eventStartTime ?? this.eventStartTime,
      eventEndTime: eventEndTime ?? this.eventEndTime,
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
      'isExpense': isExpense,
      'billCategory': billCategory,
      'note': note,
      'paymentMethod': paymentMethod,
      'merchantName': merchantName,
      'billTime': billTime?.toIso8601String(),
      'summary': summary,
      'infoSections': infoSections.map((e) => e.toJson()).toList(),
      'clothingName': clothingName,
      'clothingType': clothingType,
      'clothingColors': clothingColors,
      'clothingSeasons': clothingSeasons,
      'clothingBrand': clothingBrand,
      'clothingPrice': clothingPrice,
      'clothingSize': clothingSize,
      'clothingPurchaseDate': clothingPurchaseDate,
      'customClothingSizes': customClothingSizes,
      'customShoeSizes': customShoeSizes,
      'eventName': eventName,
      'eventStartTime': eventStartTime?.toIso8601String(),
      'eventEndTime': eventEndTime?.toIso8601String(),
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
      isExpense: json['isExpense'] as bool?,
      billCategory: json['billCategory'] as String?,
      note: json['note'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      merchantName: json['merchantName'] as String?,
      billTime: json['billTime'] != null
          ? DateTime.parse(json['billTime'] as String)
          : null,
      summary: json['summary'] as String?,
      infoSections:
          (json['infoSections'] as List<dynamic>?)
              ?.map((e) => InfoSection.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      clothingName: json['clothingName'] as String?,
      clothingType: json['clothingType'] as String?,
      clothingColors:
          (json['clothingColors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      clothingSeasons:
          (json['clothingSeasons'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      clothingBrand: json['clothingBrand'] as String?,
      clothingPrice: json['clothingPrice'] as String?,
      clothingSize: json['clothingSize'] as String?,
      clothingPurchaseDate: json['clothingPurchaseDate'] as String?,
      customClothingSizes:
          (json['customClothingSizes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      customShoeSizes:
          (json['customShoeSizes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      eventName: json['eventName'] as String?,
      eventStartTime: json['eventStartTime'] != null
          ? DateTime.tryParse(json['eventStartTime'] as String)
          : null,
      eventEndTime: json['eventEndTime'] != null
          ? DateTime.tryParse(json['eventEndTime'] as String)
          : null,
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
      case MemoryCategory.clothing:
        if (clothingType != null && clothingType!.isNotEmpty) {
          details.add(clothingType!);
        }
        if (clothingBrand != null && clothingBrand!.isNotEmpty) {
          details.add(clothingBrand!);
        }
        if (clothingPrice != null && clothingPrice!.isNotEmpty) {
          details.add(clothingPrice!);
        }
        break;
      case MemoryCategory.note:
        break;
    }

    return details;
  }
}
