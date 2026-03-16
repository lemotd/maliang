import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_button.dart';
import '../utils/scroll_edge_haptic.dart';
import '../services/memory_service.dart';
import 'backup_import_page.dart';

class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  final _memoryService = MemoryService();
  bool _isExporting = false;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<Directory> _getExportDir() async {
    if (Platform.isAndroid) {
      final dir = Directory('/storage/emulated/0/Download/maliang');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return '${info.brand} ${info.model}';
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return info.utsname.machine;
    }
    return 'Unknown';
  }

  Future<void> _exportBackup() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final memories = await _memoryService.getAllMemories();
      final deviceName = await _getDeviceName();
      final now = DateTime.now();

      // 序列化每条记忆，并将图片编码为 base64
      final memoriesWithImages = <Map<String, dynamic>>[];
      for (final m in memories) {
        final json = m.toJson();

        // 编码原图
        if (m.imagePath != null) {
          final file = File(m.imagePath!);
          if (await file.exists()) {
            json['imageData'] = base64Encode(await file.readAsBytes());
          }
        }

        // 编码缩略图
        if (m.thumbnailPath != null && m.thumbnailPath != m.imagePath) {
          final file = File(m.thumbnailPath!);
          if (await file.exists()) {
            json['thumbnailData'] = base64Encode(await file.readAsBytes());
          }
        }

        memoriesWithImages.add(json);
      }

      final backupData = {
        'version': 2,
        'deviceName': deviceName,
        'exportTime': now.toIso8601String(),
        'memoryCount': memories.length,
        'memories': memoriesWithImages,
      };

      final dir = await _getExportDir();
      final fileName = 'maliang_backup_${now.millisecondsSinceEpoch}.maliang';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonEncode(backupData));

      if (mounted) {
        _showToast('导出成功：${file.path}');
      }
    } catch (e) {
      if (mounted) _showToast('导出失败：$e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    if (!filePath.endsWith('.maliang')) {
      _showToast('请选择 .maliang 格式的备份文件');
      return;
    }

    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;

      if (!data.containsKey('memories') || !data.containsKey('version')) {
        _showToast('无效的备份文件');
        return;
      }

      if (mounted) {
        final result = await Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => BackupImportPage(backupData: data),
          ),
        );
        if (result == true && mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      _showToast('读取备份文件失败');
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      _buildItem(
                        context,
                        title: '导出备份',
                        subtitle: '导出到 Download/maliang 目录内',
                        icon: CupertinoIcons.arrow_up_doc,
                        isLoading: _isExporting,
                        onTap: _exportBackup,
                      ),
                      _buildItem(
                        context,
                        title: '从文件导入数据',
                        subtitle: '从备份文件恢复数据',
                        icon: CupertinoIcons.arrow_down_doc,
                        onTap: _pickAndImport,
                      ),
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
          height: isCollapsed ? 56 : 110,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 大标题
              Positioned(
                left: 20,
                right: 60,
                top: 64,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  opacity: isCollapsed ? 0 : 1,
                  child: Text(
                    '备份与恢复',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF1A1A1A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              // 小标题
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
                      '备份与恢复',
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
              // 返回按钮
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

  Widget _buildItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _PressableItem(
      onTap: isLoading ? () {} : onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary(isDark).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: isLoading
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary(isDark),
                        ),
                      ),
                    )
                  : Icon(icon, size: 20, color: AppColors.primary(isDark)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.onSurface(isDark),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurfaceQuaternary(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: AppColors.onSurfaceQuaternary(isDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _PressableItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableItem({required this.child, required this.onTap});

  @override
  State<_PressableItem> createState() => _PressableItemState();
}

class _PressableItemState extends State<_PressableItem> {
  bool _isPressed = false;

  void _handleTap() async {
    setState(() => _isPressed = true);
    await Future.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() => _isPressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {},
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
