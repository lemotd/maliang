import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'widgets/main_app_bar.dart';
import 'widgets/swipeable_memory_item.dart';
import 'widgets/skeleton_list_item.dart';
import 'pages/settings_page.dart';
import 'models/memory_item.dart';
import 'services/memory_service.dart';
import 'services/ai_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

class _HomePageState extends State<HomePage> {
  final _memoryService = MemoryService();
  final _aiService = AiService();
  final _imagePicker = ImagePicker();
  List<MemoryItem> _memories = [];
  int _loadingCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMemories();
    _initShareListener();
  }

  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);
    final memories = await _memoryService.getAllMemories();
    setState(() {
      _memories = memories;
      _isLoading = false;
    });
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

  Future<void> _processImageAsync(String sharedPath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final localPath = '${directory.path}/$fileName';

      final sharedFile = File(sharedPath);
      if (await sharedFile.exists()) {
        await sharedFile.copy(localPath);
      }

      final result = await _aiService.analyzeImage(localPath);
      final memory = _aiService.parseAnalysisResult(
        result,
        localPath,
        localPath,
      );

      if (memory != null) {
        await _memoryService.addMemory(memory);
        final memories = await _memoryService.getAllMemories();
        if (mounted) {
          setState(() {
            _memories = memories;
            _loadingCount--;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCount--;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('处理失败: $e'),
            backgroundColor: const Color(0xFFFF3B30),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteMemory(MemoryItem memory) async {
    await _memoryService.deleteMemory(memory.id);
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
    await _loadMemories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: MainAppBar(
        onSettingsTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
        },
      ),
      body: _buildBody(),
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007AFF).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          onPressed: _pickImage,
          icon: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
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
              Icons.note_add_outlined,
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
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
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
                                color: memory.category.color.withOpacity(0.1),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                    Icons.broken_image,
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
                  Icons.delete_outline,
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
                leading: const Icon(Icons.close),
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
