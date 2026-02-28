import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/memory_item.dart';

typedef MemoryActionCallback = void Function(int? memoryIdHash);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _channel = MethodChannel(
    'com.maliang.maliang_notes/notification',
  );

  bool _initialized = false;
  MemoryActionCallback? onCompleteMemory;
  MemoryActionCallback? onOpenDetail;

  Future<void> initialize() async {
    if (_initialized) return;

    _channel.setMethodCallHandler(_handleMethodCall);
    _initialized = true;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('收到原生调用: ${call.method}, 参数: ${call.arguments}');

    switch (call.method) {
      case 'onCompleteMemory':
        final id = call.arguments['id'] as int?;
        debugPrint('完成事项 ID: $id');
        if (id != null && onCompleteMemory != null) {
          onCompleteMemory!(id);
        }
        break;
      case 'onOpenDetail':
        final id = call.arguments['id'] as int?;
        debugPrint('打开详情 ID: $id');
        if (id != null && onOpenDetail != null) {
          onOpenDetail!(id);
        }
        break;
    }
  }

  Future<void> showLiveUpdateNotification(MemoryItem memory) async {
    if (!_initialized) await initialize();

    try {
      await _channel.invokeMethod('showLiveUpdateNotification', {
        'id': memory.id.hashCode,
        'title': memory.title,
        'category': memory.category.label,
      });
    } catch (e) {
      debugPrint('显示实时通知失败: $e');
    }
  }

  Future<void> cancelNotification(String memoryId) async {
    try {
      await _channel.invokeMethod('cancelNotification', {
        'id': memoryId.hashCode,
      });
    } catch (e) {
      debugPrint('取消通知失败: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _channel.invokeMethod('cancelAllNotifications');
    } catch (e) {
      debugPrint('取消所有通知失败: $e');
    }
  }

  Future<bool> requestNotificationPermission() async {
    return true;
  }
}
