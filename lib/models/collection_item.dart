class CollectionItem {
  final String id;
  final String name;
  final String description;
  final List<String> memoryIds;
  final DateTime createdAt;

  CollectionItem({
    required this.id,
    required this.name,
    this.description = '',
    this.memoryIds = const [],
    required this.createdAt,
  });

  CollectionItem copyWith({
    String? name,
    String? description,
    List<String>? memoryIds,
  }) {
    return CollectionItem(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      memoryIds: memoryIds ?? this.memoryIds,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'memoryIds': memoryIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      memoryIds:
          (json['memoryIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
