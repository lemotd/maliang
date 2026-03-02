import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'widgets/main_app_bar.dart';
import 'widgets/swipeable_memory_item.dart';
import 'widgets/skeleton_list_item.dart';
import 'pages/settings_page.dart';
import 'models/memory_item.dart';
import 'services/memory_service.dart';
import 'services/ai_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const MaliangNotesApp());
}

class MaliangNotesApp extends StatelessWidget {
  const MaliangNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '马良神记',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007AFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _memoryService = MemoryService();
  final _aiService = AiService();
  final _notificationService = NotificationService();
  final _imagePicker = ImagePicker();
  List<MemoryItem> _memories = [];
  int _loadingCount = 0;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  // 待处理的详情页请求
  int? _pendingDetailMemoryIdHash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotificationService();
    _loadMemories();
    _initShareListener();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 应用恢复时检查待处理的完成请求
      _checkPendingCompletesAndRefresh();
    }
  }

  Future<void> _checkPendingCompletesAndRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingCompletes = prefs.getStringList('pending_completes') ?? [];

    debugPrint('应用恢复，检查待处理的完成请求: $pendingCompletes');

    if (pendingCompletes.isNotEmpty) {
      for (final idHashStr in pendingCompletes) {
        final idHash = int.tryParse(idHashStr);
        if (idHash != null) {
          final memory = _memories
              .where((m) => m.id.hashCode == idHash)
              .firstOrNull;
          if (memory != null && !memory.isCompleted) {
            debugPrint('标记事项为完成: ${memory.id}');
            await _memoryService.toggleCompleted(memory.id);
          }
        }
      }

      // 清除待处理列表
      await prefs.remove('pending_completes');

      // 重新加载列表
      await _loadMemories();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initNotificationService() async {
    await _notificationService.initialize();
    await _notificationService.requestNotificationPermission();

    // 设置通知回调
    _notificationService.onCompleteMemory = (memoryIdHash) async {
      debugPrint('收到完成回调: memoryIdHash=$memoryIdHash');
      // 根据 hashCode 找到对应的 memory
      final memory = _memories
          .where((m) => m.id.hashCode == memoryIdHash)
          .firstOrNull;
      debugPrint('找到对应事项: ${memory != null}');
      if (memory != null) {
        debugPrint('标记事项为完成: ${memory.id}');
        await _memoryService.toggleCompleted(memory.id);
        final memories = await _memoryService.getAllMemories();
        if (mounted) {
          setState(() {
            _memories = memories;
          });
        }
      }
    };

    _notificationService.onOpenDetail = (memoryIdHash) {
      _handleOpenDetailRequest(memoryIdHash);
    };
  }

  void _handleOpenDetailRequest(int? memoryIdHash) {
    if (memoryIdHash == null) return;

    // 根据 hashCode 找到对应的 memory 并打开详情页
    final memory = _memories
        .where((m) => m.id.hashCode == memoryIdHash)
        .firstOrNull;
    if (memory != null && mounted) {
      // 使用 WidgetsBinding 确保 UI 已经准备好
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showMemoryDetail(memory);
        }
      });
    } else if (_isLoading || _memories.isEmpty) {
      // 如果数据还在加载中，保存请求等加载完成后再处理
      _pendingDetailMemoryIdHash = memoryIdHash;
    }
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);
    final memories = await _memoryService.getAllMemories();
    setState(() {
      _memories = memories;
      _isLoading = false;
    });

    // 为所有待办事项显示通知
    await _updateAllPendingNotifications();

    // 检查待处理的完成请求
    await _checkPendingCompletes();

    // 检查是否有待处理的详情页请求
    if (_pendingDetailMemoryIdHash != null) {
      final memory = _memories
          .where((m) => m.id.hashCode == _pendingDetailMemoryIdHash)
          .firstOrNull;
      if (memory != null && mounted) {
        _pendingDetailMemoryIdHash = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showMemoryDetail(memory);
        });
      }
    }
  }

  Future<void> _checkPendingCompletes() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingCompletes = prefs.getStringList('pending_completes') ?? [];

    debugPrint('检查待处理的完成请求: $pendingCompletes');

    if (pendingCompletes.isNotEmpty) {
      for (final idHashStr in pendingCompletes) {
        final idHash = int.tryParse(idHashStr);
        debugPrint('处理完成请求: idHash=$idHash');
        if (idHash != null) {
          final memory = _memories
              .where((m) => m.id.hashCode == idHash)
              .firstOrNull;
          debugPrint('找到对应事项: ${memory != null}');
          if (memory != null && !memory.isCompleted) {
            debugPrint('标记事项为完成: ${memory.id}');
            await _memoryService.toggleCompleted(memory.id);
          }
        }
      }

      // 清除待处理列表
      await prefs.remove('pending_completes');

      // 重新加载列表
      final memories = await _memoryService.getAllMemories();
      if (mounted) {
        setState(() {
          _memories = memories;
        });
      }
    }
  }

  Future<void> _updateAllPendingNotifications() async {
    // 先取消所有通知
    await _notificationService.cancelAllNotifications();

    // 为所有待办事项显示通知
    final pendingMemories = _memories.where((m) => !m.isCompleted);
    debugPrint('待办事项数量: ${pendingMemories.length}');
    for (final memory in pendingMemories) {
      debugPrint('显示通知: ${memory.title}, id.hashCode=${memory.id.hashCode}');
      await _notificationService.showLiveUpdateNotification(memory);
    }
  }

  void _initShareListener() {
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) => _handleSharedMedia(value),
      onError: (err) => debugPrint('分享接收错误: $err'),
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _handleSharedMedia(value);
      }
    });
  }

  Future<void> _pickImage() async {
    final hasKey = await _aiService.hasApiKey();
    if (!hasKey) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先在设置中填写API密钥'),
            backgroundColor: Color(0xFFFF3B30),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
      }
      return;
    }

    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      _processImage(image.path);
    }
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> files) async {
    if (_loadingCount > 0) return;

    final hasKey = await _aiService.hasApiKey();
    if (!hasKey) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先在设置中填写API密钥'),
            backgroundColor: Color(0xFFFF3B30),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsPage()),
        );
      }
      return;
    }

    for (final file in files) {
      if (file.type == SharedMediaType.image) {
        _processImage(file.path);
      }
    }
  }

  void _processImage(String sharedPath) {
    setState(() {
      _loadingCount++;
    });

    _processImageAsync(sharedPath);
  }

  Future<String?> _copySharedImageToLocal(String sharedPath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final localPath = '${directory.path}/$fileName';

      final sharedFile = File(sharedPath);
      if (await sharedFile.exists()) {
        await sharedFile.copy(localPath);
        return localPath;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<MemoryItem?> _analyzeImageWithAI(String imagePath) async {
    try {
      final result = await _aiService.analyzeImage(imagePath);
      debugPrint('AI分析结果: $result');
      final memory = _aiService.parseAnalysisResult(
        result,
        imagePath,
        imagePath,
      );
      return memory;
    } catch (e) {
      debugPrint('AI分析错误: $e');
      return null;
    }
  }

  Future<bool> _saveMemoryAndUpdateUI(MemoryItem memory) async {
    try {
      await _memoryService.addMemory(memory);
      final memories = await _memoryService.getAllMemories();
      if (mounted) {
        setState(() {
          _memories = memories;
          _loadingCount--;
        });

        // 显示待办事项通知
        if (!memory.isCompleted) {
          await _notificationService.showLiveUpdateNotification(memory);
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void _handleProcessingError(Object error) {
    if (mounted) {
      setState(() {
        _loadingCount--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('处理失败: $error'),
          backgroundColor: const Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _processImageAsync(String sharedPath) async {
    try {
      final localPath = await _copySharedImageToLocal(sharedPath);
      if (localPath == null) {
        _handleProcessingError('文件复制失败');
        return;
      }

      final memory = await _analyzeImageWithAI(localPath);
      if (memory == null) {
        _handleProcessingError('AI 分析失败');
        return;
      }

      final success = await _saveMemoryAndUpdateUI(memory);
      if (!success) {
        _handleProcessingError('保存失败');
      }
    } catch (e) {
      _handleProcessingError(e);
    }
  }

  Future<void> _deleteMemory(MemoryItem memory) async {
    await _memoryService.deleteMemory(memory.id);
    await _notificationService.cancelNotification(memory.id);
    if (memory.imagePath != null) {
      final file = File(memory.imagePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _loadMemories();
  }

  Future<void> _toggleComplete(MemoryItem memory) async {
    await _memoryService.toggleCompleted(memory.id);
    final memories = await _memoryService.getAllMemories();
    if (mounted) {
      setState(() {
        _memories = memories;
      });

      // 获取更新后的事项
      final updatedMemory = memories.firstWhere((m) => m.id == memory.id);

      if (updatedMemory.isCompleted) {
        // 事项已完成，取消通知
        await _notificationService.cancelNotification(memory.id);
      } else {
        // 事项未完成，显示通知
        await _notificationService.showLiveUpdateNotification(updatedMemory);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          MainAppBar(
            scrollOffset: _scrollOffset,
            onSettingsTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _AddButton(onPressed: _pickImage),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasLoading = _loadingCount > 0;
    final hasMemories = _memories.isNotEmpty || hasLoading;

    if (!hasMemories) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.square_pencil,
              size: 64,
              color: const Color(0xFFC7C7CC),
            ),
            const SizedBox(height: 16),
            const Text(
              '开始记录你的第一条记忆',
              style: TextStyle(fontSize: 16, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击下方按钮或分享图片',
              style: TextStyle(fontSize: 14, color: Color(0xFFC7C7CC)),
            ),
          ],
        ),
      );
    }

    final totalItems = _loadingCount + _memories.length;

    return RefreshIndicator(
      onRefresh: _loadMemories,
      child: ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: totalItems,
        itemBuilder: (context, index) {
          if (index < _loadingCount) {
            return const SkeletonListItem();
          }
          final memoryIndex = index - _loadingCount;
          final memory = _memories[memoryIndex];
          return SwipeableMemoryItem(
            memory: memory,
            onTap: () => _showMemoryDetail(memory),
            onDelete: () => _confirmDelete(memory),
            onToggleComplete: () => _toggleComplete(memory),
          );
        },
      ),
    );
  }

  void _showMemoryDetail(MemoryItem memory) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.transparent,
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            builder: (context, scrollController) => GestureDetector(
              onTap: () {},
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: memory.category.color.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      memory.category.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: memory.category.color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${memory.createdAt.year}年${memory.createdAt.month}月${memory.createdAt.day}日',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                memory.title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            if (memory.imagePath != null) ...[
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(memory.imagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 200,
                                      color: const Color(0xFFF2F2F7),
                                      child: const Center(
                                        child: Icon(
                                          CupertinoIcons.photo,
                                          color: Color(0xFFC7C7CC),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(MemoryItem memory) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  CupertinoIcons.trash,
                  color: Color(0xFFFF3B30),
                ),
                title: const Text(
                  '删除记忆',
                  style: TextStyle(color: Color(0xFFFF3B30)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMemory(memory);
                },
              ),
              ListTile(
                leading: const Icon(CupertinoIcons.xmark),
                title: const Text('取消'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AddButton({required this.onPressed});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _resetController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isInBounds = true;
  static const double _boundsRadius = 40;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.15), weight: 50),
      ],
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
    _colorAnimation = ColorTween(
      begin: const Color(0xFF007AFF),
      end: const Color(0xFF5AC8FA),
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressController.dispose();
    _resetController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _resetController.stop();
    setState(() {
      _isDragging = true;
      _isInBounds = true;
      _dragOffset = Offset.zero;
    });
    _pressController.forward();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    setState(() {
      _dragOffset += details.delta;
      final distance = _dragOffset.distance;
      _isInBounds = distance < _boundsRadius;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final wasInBounds = _isInBounds;
    final startOffset = _dragOffset;

    if (_isDragging && wasInBounds) {
      widget.onPressed();
    }

    setState(() {
      _isDragging = false;
    });

    _pressController.reverse();
    _animateDragReset(startOffset);
  }

  Future<void> _animateDragReset(Offset startOffset) async {
    final animation = Tween<Offset>(begin: startOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _resetController,
            curve: const Cubic(0.25, 1.0, 0.5, 1.0),
          ),
        );

    _resetController.reset();

    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });

    await _resetController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pressController, _resetController]),
        builder: (context, child) {
          final dragDistance = _dragOffset.distance;
          final dx = _dragOffset.dx;
          final dy = _dragOffset.dy;

          final stretchFactor = 1.0 + (dragDistance / 100).clamp(0.0, 0.5);

          Alignment anchorAlignment = Alignment.center;
          double scaleX = 1.0;
          double scaleY = 1.0;

          if (dragDistance > 5) {
            final totalAbs = dx.abs() + dy.abs();
            if (totalAbs > 0) {
              final horizontalWeight = dx.abs() / totalAbs;
              final verticalWeight = dy.abs() / totalAbs;

              scaleX = 1.0 + (stretchFactor - 1.0) * horizontalWeight;
              scaleY = 1.0 + (stretchFactor - 1.0) * verticalWeight;

              final anchorX = dx.abs() > 0.1
                  ? -dx.sign * horizontalWeight
                  : 0.0;
              final anchorY = dy.abs() > 0.1 ? -dy.sign * verticalWeight : 0.0;
              anchorAlignment = Alignment(anchorX, anchorY);
            }
          }

          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform(
              transform: Matrix4.identity()..scale(scaleX, scaleY),
              alignment: anchorAlignment,
              child: _buildButton(
                _colorAnimation.value ?? const Color(0xFF007AFF),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildButton(Color color) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 28),
    );
  }
}
