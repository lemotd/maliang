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

  MemoryItem({
    required this.id,
    required this.title,
    required this.category,
    this.imagePath,
    this.thumbnailPath,
    required this.createdAt,
    this.rawContent,
    this.isCompleted = false,
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
    );
  }
}
