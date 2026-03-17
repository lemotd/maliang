import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/collection_item.dart';

class CollectionService {
  static const String _key = 'custom_collections';

  Future<List<CollectionItem>> getAllCollections() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final data = prefs.getString(_key);
    if (data == null) return [];
    final list = jsonDecode(data) as List<dynamic>;
    return list
        .map((e) => CollectionItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCollection(CollectionItem item) async {
    final all = await getAllCollections();
    final idx = all.indexWhere((c) => c.id == item.id);
    if (idx != -1) {
      all[idx] = item;
    } else {
      all.insert(0, item);
    }
    await _save(all);
  }

  Future<void> deleteCollection(String id) async {
    final all = await getAllCollections();
    all.removeWhere((c) => c.id == id);
    await _save(all);
  }

  Future<void> _save(List<CollectionItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final json = items.map((e) => e.toJson()).toList();
    await prefs.setString(_key, jsonEncode(json));
  }
}
