import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'widgets/main_app_bar.dart';
import 'pages/memory_detail_page.dart';
import 'widgets/memory_list_item.dart';
import 'widgets/collection_section.dart';
import 'pages/settings_page.dart';
import 'models/memory_item.dart';
import 'services/memory_service.dart';
import 'services/ai_service.dart';
import 'services/notification_service.dart';
import 'services/image_cache_service.dart';
import 'theme/app_colors.dart';
import 'utils/scroll_edge_haptic.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 增加图片缓存大小
  PaintingBinding.instance.imageCache.maximumSize = 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      200 * 1024 * 1024; // 200MB

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  runApp(const MaliangNotesApp());
}

class MaliangNotesApp extends StatefulWidget {
  const MaliangNotesApp({super.key});

  @override
  State<MaliangNotesApp> createState() => _MaliangNotesAppState();
}

class _MaliangNotesAppState extends State<MaliangNotesApp> {
  bool _imagePrecached = false;

  Future<void> _precacheImage(BuildContext context) async {
    if (!_imagePrecached) {
      await precacheImage(AssetImage('assets/bill_top_picture.png'), context);
      _imagePrecached = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 在 build 方法中预加载图片
    if (!_imagePrecached) {
      _precacheImage(context);
    }

    return MaterialApp(
      title: '马良神记',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('zh', 'TW'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryLight,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.surfaceLowLight,
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
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryDark,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.surfaceLowDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
      ),
      themeMode: ThemeMode.system,
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
  final Set<String> _newlyAddedIds = {};
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('请先在设置中填写API密钥'),
            backgroundColor: AppColors.warning(isDark),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => const SettingsPage()),
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('请先在设置中填写API密钥'),
            backgroundColor: AppColors.warning(isDark),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => const SettingsPage()),
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
      debugPrint('开始AI分析图片: $imagePath');
      final result = await _aiService.analyzeImage(imagePath);
      debugPrint('AI分析结果: $result');
      if (result == null) {
        debugPrint('AI分析返回null');
        return null;
      }
      final memory = _aiService.parseAnalysisResult(
        result,
        imagePath,
        imagePath,
      );
      debugPrint('解析后的memory: ${memory?.title}');
      return memory;
    } on ApiKeyInvalidException catch (e) {
      debugPrint('API密钥无效: $e');
      // 跳转到设置页面
      if (mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => const SettingsPage()),
        );
      }
      return null;
    } catch (e, stackTrace) {
      debugPrint('AI分析错误: $e');
      debugPrint('堆栈: $stackTrace');
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
          _newlyAddedIds.add(memory.id);
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
      final isDark = Theme.of(context).brightness == Brightness.dark;
      setState(() {
        _loadingCount--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('处理失败: $error'),
          backgroundColor: AppColors.warning(isDark),
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
        _handleProcessingError('AI 分析失败，请重试');
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

    // 删除图片缓存
    final imageCacheService = ImageCacheService();
    imageCacheService.removeFromCache(memory.thumbnailPath);
    imageCacheService.removeFromCache(memory.imagePath);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.surfaceLow(isDark),
      body: Column(
        children: [
          MainAppBar(
            scrollOffset: _scrollOffset,
            onSettingsTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (context) => const SettingsPage()),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasLoading = _loadingCount > 0;
    final hasMemories = _memories.isNotEmpty || hasLoading;

    if (!hasMemories) {
      // 获取 MainAppBar 占用的高度（包含状态栏），使内容相对整个屏幕居中
      final statusBarHeight = MediaQuery.of(context).padding.top;
      final appBarHeight = _scrollOffset > 20 ? 56.0 : 130.0;
      final topOffset = statusBarHeight + appBarHeight;

      return Transform.translate(
        offset: Offset(0, -topOffset / 2),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/home_empty.png',
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 6),
              Text(
                '开始，收集碎片记忆',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceQuaternary(isDark),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '点击下方按钮或分享图片到这里',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurfaceOctonary(isDark),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalItems = _loadingCount + _memories.length;

    return ScrollEdgeHaptic(
      child: ListView.builder(
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      cacheExtent: 500,
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      itemCount: totalItems + 2, // +2 for collection section and memory title
      itemBuilder: (context, index) {
        if (index == 0) {
          return CollectionSection(memories: _memories);
        }
        if (index == 1) {
          return _buildMemoryTitle(isDark);
        }

        final adjustedIndex = index - 2;
        if (adjustedIndex < _loadingCount) {
          return const MemoryListItem(isLoading: true);
        }
        final memoryIndex = adjustedIndex - _loadingCount;
        final memory = _memories[memoryIndex];
        final isNew = _newlyAddedIds.contains(memory.id);
        return MemoryListItem(
          memory: memory,
          isNew: isNew,
          onAnimationComplete: () {
            _newlyAddedIds.remove(memory.id);
          },
          onTap: () => _showMemoryDetail(memory),
          onDelete: () => _deleteMemory(memory),
          onToggleComplete: () => _toggleComplete(memory),
        );
      },
    ),
    );
  }

  Widget _buildMemoryTitle(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 24),
          child: Text(
            '记忆',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface(isDark),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _showMemoryDetail(MemoryItem memory) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => MemoryDetailPage(memory: memory),
      ),
    ).then((updatedMemory) {
      debugPrint('返回数据: $updatedMemory');
      if (updatedMemory != null && updatedMemory is MemoryItem) {
        debugPrint('更新列表项: ${updatedMemory.title}');
        // 更新列表中的对应项
        final index = _memories.indexWhere((m) => m.id == updatedMemory.id);
        debugPrint('找到索引: $index');
        if (index != -1) {
          setState(() {
            _memories[index] = updatedMemory;
          });
          // 只有未完成的事项才更新通知
          if (!updatedMemory.isCompleted) {
            _notificationService.showLiveUpdateNotification(updatedMemory);
          }
        }
      }
    });
  }

  List<Widget> _buildDetailInfo(MemoryItem memory) {
    final List<Widget> widgets = [];

    switch (memory.category) {
      case MemoryCategory.pickupCode:
        // 取餐码详细信息
        if (memory.shopName != null ||
            memory.pickupCode != null ||
            memory.dishName != null) {
          widgets.add(const SizedBox(height: 16));
          widgets.add(
            _buildInfoCard([
              if (memory.shopName != null)
                _buildInfoRow('店铺名称', memory.shopName!),
              if (memory.pickupCode != null)
                _buildInfoRow('取餐码', memory.pickupCode!),
              if (memory.dishName != null)
                _buildInfoRow('餐品名称', memory.dishName!),
            ]),
          );
        }
        break;
      case MemoryCategory.packageCode:
        // 取件码详细信息
        if (memory.expressCompany != null ||
            memory.pickupCode != null ||
            memory.pickupAddress != null ||
            memory.productType != null ||
            memory.trackingNumber != null) {
          widgets.add(const SizedBox(height: 16));
          widgets.add(
            _buildInfoCard([
              if (memory.expressCompany != null)
                _buildInfoRow('快递公司', memory.expressCompany!),
              if (memory.pickupCode != null)
                _buildInfoRow('取件码', memory.pickupCode!),
              if (memory.pickupAddress != null)
                _buildInfoRow('取件地址', memory.pickupAddress!),
              if (memory.productType != null)
                _buildInfoRow('商品类型', memory.productType!),
              if (memory.trackingNumber != null)
                _buildInfoRow('快递单号', memory.trackingNumber!),
            ]),
          );
        }
        break;
      case MemoryCategory.bill:
        // 账单详细信息
        if (memory.amount != null ||
            memory.paymentMethod != null ||
            memory.merchantName != null) {
          widgets.add(const SizedBox(height: 16));
          widgets.add(
            _buildInfoCard([
              if (memory.amount != null) _buildInfoRow('金额', memory.amount!),
              if (memory.paymentMethod != null)
                _buildInfoRow('支付方式', memory.paymentMethod!),
              if (memory.merchantName != null)
                _buildInfoRow('商户名称', memory.merchantName!),
            ]),
          );
        }
        break;
      case MemoryCategory.clothing:
        // 服饰详细信息
        if (memory.clothingType != null ||
            memory.clothingBrand != null ||
            memory.clothingPrice != null) {
          widgets.add(const SizedBox(height: 16));
          widgets.add(
            _buildInfoCard([
              if (memory.clothingType != null)
                _buildInfoRow('分类', memory.clothingType!),
              if (memory.clothingBrand != null)
                _buildInfoRow('品牌', memory.clothingBrand!),
              if (memory.clothingPrice != null)
                _buildInfoRow('价格', memory.clothingPrice!),
            ]),
          );
        }
        break;
      case MemoryCategory.note:
        // 随手记无详细信息
        break;
    }

    return widgets;
  }

  Widget _buildInfoCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer(isDark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: _addDividers(children)),
      ),
    );
  }

  List<Widget> _addDividers(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: 16,
            endIndent: 16,
            color: AppColors.outline(isDark),
          ),
        );
      }
    }
    return result;
  }

  Widget _buildInfoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.onSurfaceQuaternary(isDark),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.onSurface(isDark),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              _showToast('已复制到剪贴板');
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                CupertinoIcons.doc_on_doc,
                size: 18,
                color: AppColors.onSurfaceOctonary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    final context = this.context;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) => _ToastWidget(message: message),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  }

  void _confirmDelete(MemoryItem memory) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceHigh(isDark),
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
                leading: Icon(
                  CupertinoIcons.trash,
                  color: AppColors.warning(isDark),
                ),
                title: Text(
                  '删除记忆',
                  style: TextStyle(color: AppColors.warning(isDark)),
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
      begin: AppColors.primaryLight,
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
                _colorAnimation.value ?? AppColors.primaryLight,
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

class _ToastWidget extends StatefulWidget {
  final String message;
  const _ToastWidget({required this.message});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                widget.message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
