import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// 监听滚动通知，在触顶/触底时触发一次轻震动。
/// 如果已经在顶部/底部，继续滑动不会重复触发。
/// 如果内容不足一屏（无法滚动），不触发震动。
///
/// 用法：在 Widget 树中包裹 ScrollEdgeHaptic(child: ...)
class ScrollEdgeHaptic extends StatefulWidget {
  final Widget child;
  final Axis axis;
  const ScrollEdgeHaptic({
    super.key,
    required this.child,
    this.axis = Axis.vertical,
  });

  @override
  State<ScrollEdgeHaptic> createState() => _ScrollEdgeHapticState();
}

class _ScrollEdgeHapticState extends State<ScrollEdgeHaptic> {
  bool _wasAtTop = true;
  bool _wasAtBottom = false;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.child,
    );
  }

  bool _onScroll(ScrollNotification notification) {
    final metrics = notification.metrics;

    // 只响应指定轴向的滚动
    if (metrics.axis != widget.axis) return false;

    // 内容不足一屏，不触发
    if (metrics.maxScrollExtent <= 0) return false;

    final atTop = metrics.pixels <= metrics.minScrollExtent;
    final atBottom = metrics.pixels >= metrics.maxScrollExtent;

    if (!_initialized) {
      _wasAtTop = atTop;
      _wasAtBottom = atBottom;
      _initialized = true;
      return false;
    }

    // 刚到达顶部（之前不在顶部）
    if (atTop && !_wasAtTop) {
      HapticFeedback.lightImpact();
    }

    // 刚到达底部（之前不在底部）
    if (atBottom && !_wasAtBottom) {
      HapticFeedback.lightImpact();
    }

    _wasAtTop = atTop;
    _wasAtBottom = atBottom;

    return false; // 不拦截通知
  }
}
