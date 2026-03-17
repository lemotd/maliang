import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../theme/app_colors.dart';
import '../models/memory_item.dart';
import '../models/collection_item.dart';
import '../services/ai_service.dart';
import '../services/collection_service.dart';
import 'ai_glow_border.dart';

class CreateCollectionSheet extends StatefulWidget {
  final List<MemoryItem> memories;
  final VoidCallback onCreated;

  const CreateCollectionSheet({
    super.key,
    required this.memories,
    required this.onCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required List<MemoryItem> memories,
    required VoidCallback onCreated,
  }) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _CollectionSheetPage(
            memories: memories,
            onCreated: onCreated,
            animation: animation,
          );
        },
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  @override
  State<CreateCollectionSheet> createState() => _CreateCollectionSheetState();
}

/// 全屏页面：遮罩(底) → 光晕(中) → 输入框(顶)
class _CollectionSheetPage extends StatelessWidget {
  final List<MemoryItem> memories;
  final VoidCallback onCreated;
  final Animation<double> animation;

  const _CollectionSheetPage({
    required this.memories,
    required this.onCreated,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Stack(
          children: [
            // 1. 黑色遮罩（淡入淡出）
            Positioned.fill(
              child: FadeTransition(
                opacity: animation,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  behavior: HitTestBehavior.opaque,
                  child: const ColoredBox(color: Colors.black26),
                ),
              ),
            ),
            // 2. 扫描光效
            Positioned.fill(
              child: IgnorePointer(
                child: _ExpandGlowWidget(screenSize: screenSize),
              ),
            ),
            // 3. 输入框（从底部滑入）
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: const _SoftBounceCurve(),
                        reverseCurve: Curves.easeIn,
                      ),
                    ),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: CreateCollectionSheet(
                    memories: memories,
                    onCreated: onCreated,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateCollectionSheetState extends State<CreateCollectionSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AiService _aiService = AiService();
  final CollectionService _collectionService = CollectionService();

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isProcessing = false;
  bool _hasText = false;
  bool _micPressed = false; // 麦克风/声波按钮按压状态
  bool _gotWords = false; // 是否识别到过文字
  Timer? _silenceTimer; // 初始静默超时
  DateTime? _listenStartTime; // 语音监听开始时间
  bool _manualStop = false; // 是否手动停止（区分自动重试）
  double _soundLevel = 0.0; // 语音音量 0.0~1.0
  bool _ignoreStatus = true; // 初始化阶段忽略所有 onStatus 回调

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _ignoreStatus = true;
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (_ignoreStatus || !mounted || _manualStop) return;
        if (status == 'done' || status == 'notListening') {
          final hadWords = _gotWords;
          // 如果还在5s窗口内且没识别到文字，自动重新监听（pauseFor会提前触发done）
          if (!hadWords && _listenStartTime != null) {
            final elapsed = DateTime.now().difference(_listenStartTime!);
            if (elapsed.inSeconds < 5) {
              // 重新开始监听，不取消silenceTimer
              _doListen();
              return;
            }
          }
          _silenceTimer?.cancel();
          setState(() {
            _isListening = false;
            _soundLevel = 0.0;
          });
          // 识别到文字后语音结束 → 自动提交
          if (hadWords && _controller.text.trim().isNotEmpty) {
            _submit();
          }
        }
      },
      onError: (error) {
        if (_ignoreStatus || !mounted || _manualStop) return;
        _silenceTimer?.cancel();
        setState(() {
          _isListening = false;
          _soundLevel = 0.0;
        });
      },
    );

    if (!_speechAvailable && mounted) {
      // 首次权限弹窗后可能返回 false，重试
      for (int i = 0; i < 3; i++) {
        await Future.delayed(Duration(milliseconds: 600 + i * 400));
        if (!mounted) return;
        _speechAvailable = await _speech.initialize();
        if (_speechAvailable) break;
      }
    }

    if (_speechAvailable && mounted) {
      // 等待引擎完全就绪后再开始监听
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        _ignoreStatus = false;
        _startListening();
      }
    }
  }

  void _startListening() {
    if (!_speechAvailable || _isListening) return;
    HapticFeedback.mediumImpact();
    _focusNode.unfocus();
    _gotWords = false;
    _manualStop = false;
    _listenStartTime = DateTime.now();
    setState(() => _isListening = true);

    // 5s 初始静默超时：如果一直没识别到文字就退出
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _isListening && !_gotWords) {
        _stopListening();
      }
    });

    // 保持 _ignoreStatus = true，listen 后延迟再开启回调
    _ignoreStatus = true;
    _doListen();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      _ignoreStatus = false;
      // 如果在保护期内引擎已经停了（_speech.isNotListening），重新 listen
      if (_isListening && !_manualStop && !_speech.isListening) {
        _doListen();
        // 再给一次保护
        _ignoreStatus = true;
        Future.delayed(const Duration(milliseconds: 1000), () {
          _ignoreStatus = false;
        });
      }
    });
  }

  void _doListen() {
    _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords;
        if (words.isNotEmpty && !_gotWords) {
          _gotWords = true;
          _silenceTimer?.cancel(); // 有声音了，取消初始超时
        }
        setState(() {
          _controller.text = words;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        });
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        // speech_to_text 返回 dB 值，通常 -2 ~ 10，归一化到 0~1
        final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
        setState(() => _soundLevel = normalized);
      },
      localeId: 'zh_CN',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
      ),
    );
  }

  void _stopListening() {
    _manualStop = true;
    _ignoreStatus = true;
    _silenceTimer?.cancel();
    _speech.stop();
    setState(() {
      _isListening = false;
      _soundLevel = 0.0;
    });
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    _stopListening();
    _focusNode.unfocus();
    setState(() => _isProcessing = true);

    try {
      final memorySummary = widget.memories
          .take(100)
          .map((m) {
            final parts = <String>[
              'id:${m.id}',
              '类型:${m.category.label}',
              '标题:${m.title}',
            ];
            if (m.note != null && m.note!.isNotEmpty) parts.add('备注:${m.note}');
            if (m.summary != null && m.summary!.isNotEmpty) {
              parts.add('摘要:${m.summary}');
            }
            if (m.clothingName != null) parts.add('名称:${m.clothingName}');
            if (m.clothingType != null) parts.add('分类:${m.clothingType}');
            if (m.billCategory != null) parts.add('账单分类:${m.billCategory}');
            if (m.merchantName != null) parts.add('商户:${m.merchantName}');
            if (m.rawContent != null && m.rawContent!.isNotEmpty) {
              final raw = m.rawContent!;
              parts.add('内容:${raw.substring(0, raw.length.clamp(0, 80))}');
            }
            return parts.join(', ');
          })
          .join('\n');

      final systemPrompt = '''你是一个智能记忆整理助手。用户会给你一条指令，描述他想创建的合集主题。
你需要从用户的记忆列表中，筛选出符合该主题的记忆条目。

请严格按以下JSON格式返回，不要返回其他内容：
{"name":"合集名称","description":"一句话描述这个合集","ids":["符合条件的记忆id列表"]}

规则：
1. name 要简洁，2-6个字
2. description 用一句话描述合集内容，20字以内
3. ids 只包含确实符合主题的记忆id
4. 如果没有符合的记忆，ids 返回空数组
5. 不要编造不存在的id''';

      final userMessage = '用户指令：$input\n\n记忆列表：\n$memorySummary';

      final result = await _aiService.chat(
        userMessage,
        systemPrompt: systemPrompt,
      );
      if (result == null || !mounted) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final jsonStr = result
          .replaceAll(RegExp(r'```json\n?'), '')
          .replaceAll(RegExp(r'\n?```'), '')
          .trim();
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
      if (jsonMatch == null) throw const FormatException('无法解析AI返回');

      final parsed = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      final name = parsed['name'] as String? ?? input;
      final description = parsed['description'] as String? ?? '';
      final ids =
          (parsed['ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final validIdSet = widget.memories.map((m) => m.id).toSet();
      final validIds = ids.where((id) => validIdSet.contains(id)).toList();

      final collection = CollectionItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        memoryIds: validIds,
        createdAt: DateTime.now(),
      );

      await _collectionService.saveCollection(collection);

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _speech.stop();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hintText = _isListening ? '想创建什么主题的合集？' : '发送你想创建的合集主题';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: _isProcessing
            ? _buildProcessingIndicator(isDark)
            : AIGlowBorder(
                borderRadius: BorderRadius.circular(100),
                intensity: _isListening ? 0.4 + _soundLevel * 0.6 : 0.25,
                child: _buildInputBar(isDark, hintText),
              ),
      ),
    );
  }

  Widget _buildProcessingIndicator(bool isDark) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(isDark),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary(isDark),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'AI 正在整理中...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.onSurfaceQuaternary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark, String hintText) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(isDark),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          // 文本输入区域
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: AppColors.onSurface(isDark),
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.onSurfaceQuaternary(isDark),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(left: 20),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          // 发送按钮（有文字时显示）/ 语音按钮
          if (_hasText)
            GestureDetector(
              onTap: _submit,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary(isDark),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            )
          else
            GestureDetector(
              onTapDown: (_) => setState(() => _micPressed = true),
              onTapUp: (_) => setState(() => _micPressed = false),
              onTapCancel: () => setState(() => _micPressed = false),
              onTap: _toggleListening,
              behavior: HitTestBehavior.opaque,
              child: AnimatedScale(
                scale: _micPressed ? 0.85 : 1.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _isListening
                        ? AppColors.primary(isDark)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                      child: _isListening
                          ? _SoundWaveBars(
                              key: const ValueKey('wave'),
                              soundLevel: _soundLevel,
                              color: Colors.white,
                            )
                          : Icon(
                              Icons.mic_none_rounded,
                              key: const ValueKey('mic'),
                              size: 22,
                              color: AppColors.onSurfaceQuaternary(isDark),
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 声波动画条
class _SoundWaveBars extends StatefulWidget {
  final double soundLevel;
  final Color color;

  const _SoundWaveBars({
    super.key,
    required this.soundLevel,
    required this.color,
  });

  @override
  State<_SoundWaveBars> createState() => _SoundWaveBarsState();
}

class _SoundWaveBarsState extends State<_SoundWaveBars>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(20, 20),
          painter: _WaveBarsPainter(
            pulseValue: _pulseController.value,
            soundLevel: widget.soundLevel,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _WaveBarsPainter extends CustomPainter {
  final double pulseValue;
  final double soundLevel;
  final Color color;

  _WaveBarsPainter({
    required this.pulseValue,
    required this.soundLevel,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const barCount = 5;
    const barWidth = 2.4;
    const gap = 1.6;
    const totalWidth = barCount * barWidth + (barCount - 1) * gap;
    final startX = cx - totalWidth / 2 + barWidth / 2;

    const baseHeights = [0.3, 0.6, 1.0, 0.6, 0.3];
    const phaseOffsets = [0.0, 0.2, 0.4, 0.6, 0.8];

    final maxBarH = size.height * 0.7;
    const minBarH = 3.0;

    for (int i = 0; i < barCount; i++) {
      final x = startX + i * (barWidth + gap);
      final phase = (pulseValue + phaseOffsets[i]) % 1.0;
      final pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2);
      final level = soundLevel * 0.7 + pulse * 0.3;
      final h = (minBarH + (maxBarH - minBarH) * baseHeights[i] * level).clamp(
        minBarH,
        maxBarH,
      );

      final barRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, cy), width: barWidth, height: h),
        const Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(barRect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveBarsPainter old) => true;
}

/// 柔和回弹曲线：轻微超出后平滑回到终点
class _SoftBounceCurve extends Curve {
  const _SoftBounceCurve();

  @override
  double transformInternal(double t) {
    // 漂浮感弹簧：极小幅度、慢速二次回弹
    if (t >= 1.0) return 1.0;
    if (t <= 0.0) return 0.0;
    final decay = math.exp(-6.0 * t);
    final raw = 1.0 - decay * math.cos(t * math.pi * 1.6);
    if (t > 0.9) {
      final blend = (t - 0.9) / 0.1;
      return raw * (1.0 - blend) + blend;
    }
    return raw;
  }
}

/// 彩色光晕从输入框底部扩散到整个屏幕的动画（内嵌在 widget 树中）
class _ExpandGlowWidget extends StatefulWidget {
  final Size screenSize;

  const _ExpandGlowWidget({required this.screenSize});

  @override
  State<_ExpandGlowWidget> createState() => _ExpandGlowWidgetState();
}

class _ExpandGlowWidgetState extends State<_ExpandGlowWidget>
    with TickerProviderStateMixin {
  late AnimationController _expandController;
  late Animation<double> _expandCurved;
  late AnimationController _fadeController;
  late Animation<double> _fadeCurved;

  @override
  void initState() {
    super.initState();
    // 扩散：600ms，easeOut 前快后慢缓慢停止
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _expandCurved = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOut,
    );
    // 淡出：900ms，用极慢结尾的曲线
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: 0.0,
    );
    _fadeCurved = CurvedAnimation(
      parent: _fadeController,
      // 自定义曲线：结尾非常慢
      curve: const Cubic(0.25, 0.1, 0.25, 0.6),
    );

    _expandController.forward().then((_) {
      if (mounted) _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _expandController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_expandCurved, _fadeCurved]),
      builder: (context, _) {
        final fade = 1.0 - _fadeCurved.value;
        return CustomPaint(
          size: widget.screenSize,
          painter: _ExpandGlowPainter(
            progress: _expandCurved.value,
            fade: fade,
          ),
        );
      },
    );
  }
}

class _ExpandGlowPainter extends CustomPainter {
  final double progress;
  final double fade;

  _ExpandGlowPainter({required this.progress, required this.fade});

  @override
  void paint(Canvas canvas, Size size) {
    if (fade <= 0.01) return;

    // 从屏幕底部中心径向扩散，覆盖整个屏幕
    final origin = Offset(size.width / 2, size.height);
    final maxRadius =
        math.sqrt(math.pow(size.width / 2, 2) + math.pow(size.height, 2)) * 2.0;

    final currentRadius = maxRadius * progress;
    if (currentRadius < 1) return;

    final baseAlpha = (0.35 * fade * fade).clamp(0.0, 0.35);

    final spots = <_GlowSpot>[
      _GlowSpot(
        dx: 0,
        dy: -0.4,
        color: const Color(0xFF8B5CF6),
        scale: 0.9,
        alpha: 1.0,
      ),
      _GlowSpot(
        dx: -0.45,
        dy: -0.5,
        color: const Color(0xFF6366F1),
        scale: 0.7,
        alpha: 0.8,
      ),
      _GlowSpot(
        dx: 0.45,
        dy: -0.45,
        color: const Color(0xFFEC4899),
        scale: 0.7,
        alpha: 0.75,
      ),
      _GlowSpot(
        dx: -0.3,
        dy: -0.7,
        color: const Color(0xFF06B6D4),
        scale: 0.6,
        alpha: 0.6,
      ),
      _GlowSpot(
        dx: 0.3,
        dy: -0.65,
        color: const Color(0xFFF59E0B),
        scale: 0.55,
        alpha: 0.5,
      ),
    ];

    for (final spot in spots) {
      final spotRadius = currentRadius * spot.scale;
      final center = Offset(
        origin.dx + currentRadius * spot.dx,
        origin.dy + currentRadius * spot.dy,
      );
      final alpha = baseAlpha * spot.alpha;
      final spotRect = Rect.fromCircle(center: center, radius: spotRadius);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            spot.color.withValues(alpha: alpha),
            spot.color.withValues(alpha: alpha * 0.5),
            spot.color.withValues(alpha: alpha * 0.15),
            spot.color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.3, 0.65, 1.0],
        ).createShader(spotRect);

      canvas.drawCircle(center, spotRadius, paint);
    }

    // 左右两侧白色高亮边，从底部向上扫过
    if (progress > 0.05) {
      final edgeAlpha = (0.95 * fade * fade).clamp(0.0, 0.95);
      // 高亮边中心从底部扫到顶部
      final sweepY = size.height * (1.3 - progress * 2.0);
      final edgeH = size.height * 0.6;
      final edgeW = size.width * 0.06;

      // 左侧 — 贴着屏幕左边缘
      final leftRect = Rect.fromLTWH(
        -edgeW * 0.5,
        sweepY - edgeH / 2,
        edgeW,
        edgeH,
      );
      final leftPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.fromRGBO(255, 255, 255, edgeAlpha),
            Color.fromRGBO(255, 255, 255, edgeAlpha * 0.5),
            const Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(leftRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRect(leftRect, leftPaint);

      // 右侧 — 贴着屏幕右边缘
      final rightRect = Rect.fromLTWH(
        size.width - edgeW * 0.5,
        sweepY - edgeH / 2,
        edgeW,
        edgeH,
      );
      final rightPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            Color.fromRGBO(255, 255, 255, edgeAlpha),
            Color.fromRGBO(255, 255, 255, edgeAlpha * 0.5),
            const Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(rightRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRect(rightRect, rightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExpandGlowPainter old) {
    return progress != old.progress || fade != old.fade;
  }
}

class _GlowSpot {
  final double dx; // 相对于 origin 的 x 偏移比例
  final double dy; // 相对于 origin 的 y 偏移比例
  final Color color;
  final double scale; // 光斑半径占总半径的比例
  final double alpha; // 透明度系数

  const _GlowSpot({
    required this.dx,
    required this.dy,
    required this.color,
    required this.scale,
    required this.alpha,
  });
}
