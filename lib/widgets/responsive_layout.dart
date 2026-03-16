import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

/// 大屏断点宽度
const double kWideScreenBreakpoint = 600;

/// 提供大屏分栏导航能力的 InheritedWidget
class DetailPaneScope extends InheritedWidget {
  final GlobalKey<NavigatorState> detailNavigatorKey;
  final void Function(Widget page, {String? key}) showDetail;

  const DetailPaneScope({
    super.key,
    required this.detailNavigatorKey,
    required this.showDetail,
    required super.child,
  });

  static DetailPaneScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DetailPaneScope>();
  }

  @override
  bool updateShouldNotify(DetailPaneScope oldWidget) => false;
}

/// 判断当前是否为大屏分栏模式
bool isWideScreen(BuildContext context) {
  return MediaQuery.of(context).size.width >= kWideScreenBreakpoint;
}

/// 从主页面点击时调用：同级切换右侧详情页
/// [key] 用于去重，相同 key 不会重复打开。不传则用 runtimeType。
bool pushToDetailPane(BuildContext context, Widget page, {String? key}) {
  final scope = DetailPaneScope.of(context);
  if (scope != null && isWideScreen(context)) {
    scope.showDetail(page, key: key);
    return true;
  }
  return false;
}

/// 大屏分栏布局壳
class ResponsiveShell extends StatefulWidget {
  final Widget masterPane;
  const ResponsiveShell({super.key, required this.masterPane});
  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  final GlobalKey<NavigatorState> _detailNavKey = GlobalKey<NavigatorState>();
  String? _currentPageKey;

  void _showDetail(Widget page, {String? key}) {
    final pageKey = key ?? page.runtimeType.toString();

    // 同一个 key 不重复打开
    if (_currentPageKey == pageKey) return;
    setState(() => _currentPageKey = pageKey);

    // 清空到空白首页，再 push 新页面（同级切换）
    _detailNavKey.currentState?.pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => page),
      (route) => route.isFirst,
    );
  }

  bool _tryPopDetail() {
    final nav = _detailNavKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (nav.canPop() == false) {
          setState(() => _currentPageKey = null);
        }
      });
      return true;
    }
    return false;
  }

  /// 监听 detail navigator 的路由变化，当回到首页时清除 key
  void _onDetailRouteChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = _detailNavKey.currentState;
      if (nav != null && !nav.canPop()) {
        setState(() => _currentPageKey = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWideScreen(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!wide) {
      return widget.masterPane;
    }

    return DetailPaneScope(
      detailNavigatorKey: _detailNavKey,
      showDetail: _showDetail,
      child: PopScope(
        canPop: _currentPageKey == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _tryPopDetail();
        },
        child: Row(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width / 3,
              child: widget.masterPane,
            ),
            Container(
              width: 0.6,
              color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
            ),
            Expanded(
              child: ClipRect(
                child: Navigator(
                  key: _detailNavKey,
                  observers: [_DetailNavObserver(_onDetailRouteChanged)],
                  onGenerateRoute: (_) =>
                      CupertinoPageRoute(builder: (_) => _EmptyDetailPage()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailNavObserver extends NavigatorObserver {
  final VoidCallback onRouteChanged;
  _DetailNavObserver(this.onRouteChanged);

  @override
  void didPop(Route route, Route? previousRoute) {
    onRouteChanged();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    onRouteChanged();
  }
}

class _EmptyDetailPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.surfaceLow(isDark),
      body: Center(
        child: Text(
          '选择一项查看详情',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.onSurfaceQuaternary(isDark),
          ),
        ),
      ),
    );
  }
}
