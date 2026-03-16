import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_button.dart';
import '../services/memory_service.dart';
import '../models/memory_item.dart';
import '../utils/scroll_edge_haptic.dart';
import '../main.dart';

class BackupImportPage extends StatefulWidget {
  final Map<String, dynamic> backupData;

  const BackupImportPage({super.key, required this.backupData});

  @override
  State<BackupImportPage> createState() => _BackupImportPageState();
}

class _BackupImportPageState extends State<BackupImportPage> {
  final _memoryService = MemoryService();
  bool _isMerge = true; // true=合并, false=覆盖
  bool _isImporting = false;
  double _scrollOffset = 0;

  String get _deviceName =>
      widget.backupData['deviceName'] as String? ?? '未知设备';
  String get _exportTime {
    final raw = widget.backupData['exportTime'] as String?;
    if (raw == null) return '未知';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  int get _memoryCount => widget.backupData['memoryCount'] as int? ?? 0;

  Future<void> _startImport() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    try {
      final memoriesJson = widget.backupData['memories'] as List<dynamic>;
      final docDir = await getApplicationDocumentsDirectory();

      final importedMemories = <MemoryItem>[];
      for (final j in memoriesJson) {
        final json = j as Map<String, dynamic>;

        // 还原图片文件
        String? imagePath = json['imagePath'] as String?;
        String? thumbnailPath = json['thumbnailPath'] as String?;

        if (json['imageData'] != null) {
          final bytes = base64Decode(json['imageData'] as String);
          final fileName =
              'img_restore_${DateTime.now().millisecondsSinceEpoch}_${importedMemories.length}.jpg';
          final file = File('${docDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          imagePath = file.path;
          // 如果没有单独的缩略图数据，缩略图也用原图路径
          if (json['thumbnailData'] == null) {
            thumbnailPath = file.path;
          }
        }

        if (json['thumbnailData'] != null) {
          final bytes = base64Decode(json['thumbnailData'] as String);
          final fileName =
              'thumb_restore_${DateTime.now().millisecondsSinceEpoch}_${importedMemories.length}.jpg';
          final file = File('${docDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          thumbnailPath = file.path;
        }

        // 用还原后的路径覆盖 json 中的路径
        json['imagePath'] = imagePath;
        json['thumbnailPath'] = thumbnailPath;

        importedMemories.add(MemoryItem.fromJson(json));
      }

      if (_isMerge) {
        final existing = await _memoryService.getAllMemories();
        final existingIds = existing.map((m) => m.id).toSet();
        for (final memory in importedMemories) {
          if (!existingIds.contains(memory.id)) {
            await _memoryService.addMemory(memory);
          }
        }
      } else {
        final existing = await _memoryService.getAllMemories();
        for (final m in existing) {
          await _memoryService.deleteMemory(m.id);
        }
        for (final memory in importedMemories) {
          await _memoryService.addMemory(memory);
        }
      }

      if (mounted) {
        // 通知首页刷新数据
        await HomePage.onDataChanged?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入成功，共 ${importedMemories.length} 条记忆'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败：$e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
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
                    padding: const EdgeInsets.only(top: 8),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    children: [
                      // 备份信息
                      _buildSectionTitle(context, '备份信息'),
                      _buildInfoCard(context),
                      const SizedBox(height: 20),
                      // 导入方式
                      _buildSectionTitle(context, '导入方式'),
                      _buildImportModeCard(context),
                      const SizedBox(height: 24),
                      // 开始导入按钮
                      _buildImportButton(context),
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
                    '选择导入内容',
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
                      '选择导入内容',
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.onSurfaceQuaternary(isDark),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildInfoRow(context, '设备名称', _deviceName),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(height: 0.6, color: AppColors.outline(isDark)),
          ),
          _buildInfoRow(context, '备份时间', _exportTime),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(height: 0.6, color: AppColors.outline(isDark)),
          ),
          _buildInfoRow(context, '记忆数量', '$_memoryCount 条'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.onSurfaceQuaternary(isDark),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.onSurface(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildImportModeCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildRadioItem(
            context,
            title: '合并数据',
            subtitle: '保留现有数据，添加新数据',
            selected: _isMerge,
            onTap: () => setState(() => _isMerge = true),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 0.6,
            color: AppColors.outline(isDark),
          ),
          _buildRadioItem(
            context,
            title: '覆盖数据',
            subtitle: '覆盖替换现有数据',
            selected: !_isMerge,
            onTap: () => setState(() => _isMerge = false),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _PressableItem(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.onSurfaceQuaternary(isDark),
                    ),
                  ),
                ],
              ),
            ),
            _AnimatedCheckRadio(
              selected: selected,
              size: 26,
              color: selected
                  ? AppColors.primary(isDark)
                  : AppColors.onSurfaceQuaternary(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _PressableItem(
        onTap: _isImporting ? () {} : _startImport,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: _isImporting
                ? AppColors.primary(isDark).withValues(alpha: 0.5)
                : AppColors.primary(isDark),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Center(
            child: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '开始导入',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedCheckRadio extends StatefulWidget {
  final bool selected;
  final double size;
  final Color color;

  const _AnimatedCheckRadio({
    required this.selected,
    required this.size,
    required this.color,
  });

  @override
  State<_AnimatedCheckRadio> createState() => _AnimatedCheckRadioState();
}

class _AnimatedCheckRadioState extends State<_AnimatedCheckRadio>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isSelecting = true;

  @override
  void initState() {
    super.initState();
    _isSelecting = true;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.selected ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_AnimatedCheckRadio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _isSelecting = true;
        _controller.duration = const Duration(milliseconds: 200);
        _controller.forward(from: 0.0);
      } else {
        _isSelecting = false;
        _controller.duration = const Duration(milliseconds: 120);
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CheckRadioPainter(
            progress: _controller.value,
            isSelecting: _isSelecting,
            color: widget.color,
            unselectedColor: widget.color,
          ),
        );
      },
    );
  }
}

class _CheckRadioPainter extends CustomPainter {
  final double progress;
  final bool isSelecting;
  final Color color;
  final Color unselectedColor;

  _CheckRadioPainter({
    required this.progress,
    required this.isSelecting,
    required this.color,
    required this.unselectedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (progress == 0) {
      // 未选中：空心圆
      final paint = Paint()
        ..color = unselectedColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius - 0.75, paint);
      return;
    }

    // 填充圆
    final fillPaint = Paint()
      ..color = color.withOpacity(progress)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, fillPaint);

    // 对勾
    final checkPaint = Paint()
      ..color = Colors.white.withOpacity(isSelecting ? 1.0 : progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final p1 = Offset(size.width * 0.27, size.height * 0.50);
    final p2 = Offset(size.width * 0.44, size.height * 0.66);
    final p3 = Offset(size.width * 0.73, size.height * 0.36);

    path.moveTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.lineTo(p3.dx, p3.dy);

    if (isSelecting) {
      // 选中：沿路径绘制
      final metrics = path.computeMetrics().first;
      final drawPath = metrics.extractPath(
        0,
        metrics.length * Curves.easeOut.transform(progress),
      );
      canvas.drawPath(drawPath, checkPaint);
    } else {
      // 取消选中：整体淡出
      canvas.drawPath(path, checkPaint);
    }
  }

  @override
  bool shouldRepaint(_CheckRadioPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      unselectedColor != oldDelegate.unselectedColor;
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
