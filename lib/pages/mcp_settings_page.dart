import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_button.dart';
import '../utils/scroll_edge_haptic.dart';
import '../utils/smooth_radius.dart';
import '../services/mcp_server_service.dart';

class _McpTool {
  final String name;
  final String description;
  const _McpTool(this.name, this.description);
}

const _mcpTools = [
  _McpTool('list_memories', '列出记忆条目（支持分类/关键词/状态筛选）'),
  _McpTool('get_memory', '获取单条记忆详情'),
  _McpTool('search_memories', '全文搜索记忆'),
  _McpTool('query_bills', '账单查询（日期/分类/金额范围）'),
  _McpTool('get_bill_summary', '账单统计摘要（周/月/年）'),
  _McpTool('add_memory', '添加新记忆'),
  _McpTool('update_memory', '更新记忆'),
  _McpTool('delete_memory', '删除记忆'),
  _McpTool('toggle_memory_completed', '切换完成状态'),
  _McpTool('export_memory_image', '导出记忆图片'),
];

class McpSettingsPage extends StatefulWidget {
  const McpSettingsPage({super.key});

  @override
  State<McpSettingsPage> createState() => _McpSettingsPageState();
}

class _McpSettingsPageState extends State<McpSettingsPage> {
  double _scrollOffset = 0;
  String _authToken = '';
  bool _mcpEnabled = false;

  static const String _keyMcpToken = 'mcp_auth_token';
  static const String _keyMcpEnabled = 'mcp_server_enabled';
  static const int _mcpPort = 8765;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString(_keyMcpToken) ?? '';
    if (token.isEmpty) {
      token = _generateToken();
      await prefs.setString(_keyMcpToken, token);
    }
    final enabled = prefs.getBool(_keyMcpEnabled) ?? false;
    setState(() {
      _authToken = token;
      _mcpEnabled = enabled;
    });
    if (enabled) {
      try {
        await McpServerService().start();
      } catch (_) {}
    }
  }

  Future<void> _setMcpEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMcpEnabled, value);
    setState(() => _mcpEnabled = value);
    if (value) {
      try {
        await McpServerService().start();
      } catch (_) {}
    } else {
      await McpServerService().stop();
    }
  }

  static String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _regenerateToken() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('重新生成 Token'),
        content: const Text('旧 Token 将立即失效，已连接的 AI 需要更新配置。'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final token = _generateToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMcpToken, token);
    setState(() => _authToken = token);
    _showToast('Token 已重新生成');
  }

  String get _mcpUrl => 'http://127.0.0.1:$_mcpPort/mcp';

  String _generateConfigJson() {
    final config = {
      'mcpServers': {
        '马良神记': {
          'type': 'streamable-http',
          'url': _mcpUrl,
          'headers': {'Authorization': 'Bearer $_authToken'},
        },
      },
    };
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(config);
  }

  void _copyConfig() {
    Clipboard.setData(ClipboardData(text: _generateConfigJson()));
    _showToast('MCP 配置已复制到剪贴板');
  }

  void _copyToken() {
    Clipboard.setData(ClipboardData(text: _authToken));
    _showToast('Token 已复制');
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: smoothRadius(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCollapsed = _scrollOffset > 50;

    return Scaffold(
      backgroundColor: AppColors.surfaceLow(isDark),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(context, isCollapsed),
            Expanded(
              child: ScrollEdgeHaptic(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification) {
                      setState(() {
                        _scrollOffset = notification.metrics.pixels;
                      });
                    }
                    return false;
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(top: 4),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    children: [
                      _buildEnableCard(context),
                      _buildTokenCard(context),
                      _buildConfigPreview(context),
                      _buildToolsCard(context),
                      const SizedBox(height: 54),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isCollapsed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: isCollapsed ? 56 : 134,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 20,
                right: 60,
                top: 64,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  opacity: isCollapsed ? 0 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MCP 配置',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFFFFFFF)
                              : const Color(0xFF1A1A1A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '让其他 AI 可读写马良神记的数据',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.onSurfaceQuaternary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 60,
                right: 60,
                top: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  opacity: isCollapsed ? 1 : 0,
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    child: Text(
                      'MCP 配置',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFF1A1A1A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 0,
                child: GlassButton(
                  icon: CupertinoIcons.back,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          height: isCollapsed ? 0.6 : 0,
          child: Container(height: 0.6, color: const Color(0x0F000000)),
        ),
      ],
    );
  }

  Widget _buildEnableCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: smoothRadius(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '启用 MCP Server',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface(isDark),
                    ),
                  ),
                ),
                CupertinoSwitch(
                  value: _mcpEnabled,
                  activeTrackColor: AppColors.primary(isDark),
                  onChanged: (value) => _setMcpEnabled(value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _mcpEnabled
                        ? const Color(0xFF34C759)
                        : AppColors.onSurfaceQuaternary(isDark),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _mcpEnabled ? '运行中 · 127.0.0.1:$_mcpPort' : '已关闭',
                  style: TextStyle(
                    fontSize: 14,
                    color: _mcpEnabled
                        ? const Color(0xFF34C759)
                        : AppColors.onSurfaceQuaternary(isDark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayToken = _authToken.length > 16
        ? '${_authToken.substring(0, 8)}····${_authToken.substring(_authToken.length - 8)}'
        : _authToken;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: smoothRadius(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'API Token',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface(isDark),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _copyToken,
                  child: Text(
                    '复制',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              displayToken,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: AppColors.onSurfaceQuaternary(isDark),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _regenerateToken,
              child: Text(
                '重新生成 Token',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigPreview(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final configJson = _generateConfigJson();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: smoothRadius(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '配置 JSON',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface(isDark),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _copyConfig,
                  child: Text(
                    '复制',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary(isDark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0D0D0D)
                    : const Color(0xFFF5F5F7),
                borderRadius: smoothRadius(12),
              ),
              child: SelectableText(
                configJson,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.5,
                  color: isDark
                      ? const Color(0xFFB0B0B0)
                      : const Color(0xFF3A3A3A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: smoothRadius(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '可用工具（${_mcpTools.length}）',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface(isDark),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_mcpTools.length, (index) {
              final tool = _mcpTools[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index < _mcpTools.length - 1 ? 10 : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'monospace',
                        color: AppColors.onSurface(isDark),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      tool.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceQuaternary(isDark),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
