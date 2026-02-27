import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/memory_item.dart';

class MemoryService {
  static const String _keyMemories = 'memories';

  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  Future<List<MemoryItem>> getAllMemories() async {
    final prefs = await _getPrefs();
    final String? data = prefs.getString(_keyMemories);
    if (data == null) return [];

    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((json) => MemoryItem.fromJson(json)).toList();
  }

  Future<void> addMemory(MemoryItem memory) async {
    final memories = await getAllMemories();
    memories.insert(0, memory);
    await _saveMemories(memories);
  }

  Future<void> updateMemory(MemoryItem memory) async {
    final memories = await getAllMemories();
    final index = memories.indexWhere((m) => m.id == memory.id);
    if (index != -1) {
      memories[index] = memory;
      await _saveMemories(memories);
    }
  }

  Future<void> deleteMemory(String id) async {
    final memories = await getAllMemories();
    memories.removeWhere((m) => m.id == id);
    await _saveMemories(memories);
  }

  Future<void> _saveMemories(List<MemoryItem> memories) async {
    final prefs = await _getPrefs();
    final jsonList = memories.map((m) => m.toJson()).toList();
    await prefs.setString(_keyMemories, jsonEncode(jsonList));
  }

  Future<void> toggleCompleted(String id) async {
    final memories = await getAllMemories();
    final index = memories.indexWhere((m) => m.id == id);
    if (index != -1) {
      memories[index] = memories[index].copyWith(
        isCompleted: !memories[index].isCompleted,
      );
      await _saveMemories(memories);
    }
  }
}
