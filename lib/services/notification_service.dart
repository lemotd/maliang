import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/memory_item.dart';

typedef MemoryActionCallback = void Function(int? memoryIdHash);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _channel = MethodChannel(
    'com.maliang.maliang_notes/notification',
  );

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  MemoryActionCallback? onCompleteMemory;
  MemoryActionCallback? onOpenDetail;

  Future<void> initialize() async {
    if (_initialized) return;

    // 初始化本地通知
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);

    _channel.setMethodCallHandler(_handleMethodCall);
    _initialized = true;
    debugPrint('通知服务初始化完成');
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
      final detailInfo = memory.getDetailInfo();
      final detailText = detailInfo.isEmpty ? '' : detailInfo.join(' · ');

      // 格式化标题，为账单添加 ¥ 符号
      String displayTitle = memory.title;
      if (memory.category == MemoryCategory.bill) {
        if (!displayTitle.contains('¥')) {
          if (!displayTitle.startsWith('-') && !displayTitle.startsWith('+')) {
            displayTitle = '-¥$displayTitle';
          } else if (displayTitle.startsWith('-')) {
            displayTitle = '-¥${displayTitle.substring(1)}';
          } else if (displayTitle.startsWith('+')) {
            displayTitle = '+¥${displayTitle.substring(1)}';
          }
        }
      }

      debugPrint(
        '调用原生通知: id=${memory.id.hashCode}, title=$displayTitle, category=${memory.category.label}, detail=$detailText',
      );
      await _channel.invokeMethod('showLiveUpdateNotification', {
        'id': memory.id.hashCode,
        'title': displayTitle,
        'category': memory.category.label,
        'detail': detailText,
      });
      debugPrint('原生通知调用成功');
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
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      debugPrint('通知权限请求结果: $granted');
      return granted ?? false;
    }
    return false;
  }
}
