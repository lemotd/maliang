import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/ai_service.dart';
import '../models/memory_item.dart';
import '../models/bill_category.dart';

class AiChatSheet extends StatefulWidget {
  final List<MemoryItem> bills;

  const AiChatSheet({super.key, required this.bills});

  static void show(BuildContext context, List<MemoryItem> bills) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, _) {
          return FadeTransition(
            opacity: animation,
            child: AiChatSheet(bills: bills),
          );
        },
      ),
    );
  }

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

enum _SheetMode { listening, typing, answering }

class _AiChatSheetState extends State<AiChatSheet>
    with TickerProviderStateMixin {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _speechInitialized = false;
  static _AiChatSheetState? _activeInstance;
  final AiService _aiService = AiService();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  _SheetMode _mode = _SheetMode.listening;
  String _recognizedText = '';
  String _previousSessionText = ''; // 之前轮次累积的文字
  String _aiResponse = '';
  bool _isAiLoading = false;
  bool _speechAvailable = false;
  Timer? _silenceTimer;

  /// 标记当前这轮监听是否收到了新文字
  bool _gotNewWordsInSession = false;

  /// 防止多次 pop
  bool _isClosing = false;

  /// 无语音 done 的连续次数，用于判断是否真的没人说话
  int _emptyDoneCount = 0;

  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _entranceController;
  late Animation<double> _capsuleAnim;
  late Animation<double> _leftBtnAnim;
  late Animation<double> _rightBtnAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    // 中间胶囊：从底部上升，结尾减速（decelerate）
    _capsuleAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutQuart),
    );
    // 左右按钮：在胶囊动画即将结束时出现，从中心向两侧展开 + 缩放 + 渐显
    _leftBtnAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    );
    _rightBtnAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    );
    _entranceController.forward();

    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _activeInstance = this;
    try {
      if (!_speechInitialized) {
        _speechAvailable = await _speech.initialize(
          onStatus: (status) => _activeInstance?._onSpeechStatus(status),
          onError: (error) => _activeInstance?._onSpeechError(error),
        );
        _speechInitialized = _speechAvailable;
      } else {
        _speechAvailable = _speech.isAvailable;
      }
    } catch (e) {
      _speechAvailable = false;
    }
    if (!mounted) return;
    if (_speechAvailable) {
      _startListening();
    } else {
      setState(() => _recognizedText = '语音不可用，正在切换键盘...');
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted && _mode == _SheetMode.listening) {
        setState(() {
          _recognizedText = '';
          _mode = _SheetMode.typing;
        });
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _focusNode.requestFocus();
        });
      }
    }
  }

  void _onSpeechStatus(String status) {
    debugPrint(
      '[Speech] onStatus: $status, text="${_recognizedText}", newWords=$_gotNewWordsInSession, closing=$_isClosing, relistening=$_isRelistening',
    );
    if (!mounted || _mode != _SheetMode.listening || _isClosing) return;
    if (_isRelistening) return;
    if (status == 'done' || status == 'notListening') {
      if (_recognizedText.isEmpty) {
        _emptyDoneCount++;
        if (_emptyDoneCount < 2) {
          // 第一次无文字 done，可能是引擎刚启动就超时，重试一次
          _relistenAfterDone();
        } else {
          // 连续两次无文字，确认没人说话 → 关闭面板
          _silenceTimer?.cancel();
          _safeClose();
        }
      } else if (_gotNewWordsInSession) {
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(seconds: 2), () {
          if (mounted &&
              _recognizedText.isNotEmpty &&
              _mode == _SheetMode.listening) {
            _sendToAi(_recognizedText);
          }
        });
        _relistenAfterDone();
      } else {
        // 重新监听后没有新文字 → 不做任何事，让 2 秒计时器自然到期后发送
        // 如果计时器已经不在跑了（极端情况），补一个
        if (_silenceTimer == null || !_silenceTimer!.isActive) {
          _silenceTimer = Timer(const Duration(seconds: 2), () {
            if (mounted &&
                _recognizedText.isNotEmpty &&
                _mode == _SheetMode.listening) {
              _sendToAi(_recognizedText);
            }
          });
        }
      }
    }
  }

  void _onSpeechError(dynamic error) {
    debugPrint(
      '[Speech] onError: $error, text="${_recognizedText}", closing=$_isClosing',
    );
    if (!mounted || _mode != _SheetMode.listening || _isClosing) return;
    if (_recognizedText.isEmpty) {
      _silenceTimer?.cancel();
      _safeClose();
    }
  }

  /// 安全关闭面板，防止多次 pop
  void _safeClose() {
    if (_isClosing || !mounted) return;
    debugPrint('[Speech] _safeClose called');
    _isClosing = true;
    _silenceTimer?.cancel();
    _speech.cancel(); // cancel 不触发 onStatus，避免残留回调
    Navigator.pop(context);
  }

  /// 语音引擎 done 后重新开始监听（用于用户还在说话的场景）
  bool _isRelistening = false;
  Future<void> _relistenAfterDone() async {
    _isRelistening = true;
    await _speech.cancel();
    await Future.delayed(const Duration(milliseconds: 200));
    _isRelistening = false;
    if (!mounted ||
        _mode != _SheetMode.listening ||
        !_speechAvailable ||
        _isClosing)
      return;
    _gotNewWordsInSession = false;
    _previousSessionText = _recognizedText; // 保存当前文字，新一轮的 partial results 会拼在后面
    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        localeId: 'zh_CN',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (_) {
      // 重新监听失败，让 2 秒计时器自动发送
    }
  }

  void _onSpeechResult(dynamic result) {
    if (!mounted) return;
    final words = result.recognizedWords as String;
    if (words.isNotEmpty) {
      _gotNewWordsInSession = true;
      _emptyDoneCount = 0;
      setState(() {
        // partial results 在同一轮监听中是累积的，直接拼接前缀
        _recognizedText = _previousSessionText + words;
      });
      // 每次有新文字，重置 2 秒静默计时器
      _silenceTimer?.cancel();
      _silenceTimer = Timer(const Duration(seconds: 2), () {
        if (mounted &&
            _recognizedText.isNotEmpty &&
            _mode == _SheetMode.listening) {
          _sendToAi(_recognizedText);
        }
      });
    }
  }

  Future<void> _startListening() async {
    if (!_speechAvailable) return;
    _silenceTimer?.cancel();
    _gotNewWordsInSession = false;
    _isRelistening = false;
    setState(() {
      _mode = _SheetMode.listening;
      _recognizedText = '';
      _previousSessionText = '';
      _aiResponse = '';
    });
    // cancel 不触发 onStatus 回调，比 stop 更干净
    await _speech.cancel();
    if (!mounted || _mode != _SheetMode.listening || _isClosing) return;
    _emptyDoneCount = 0;
    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        localeId: 'zh_CN',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (_) {}
  }

  void _stopListening() {
    _speech.cancel();
    _silenceTimer?.cancel();
  }

  void _switchToTyping() {
    _stopListening();
    setState(() => _mode = _SheetMode.typing);
    Future.delayed(const Duration(milliseconds: 100), () {
      _focusNode.requestFocus();
    });
  }

  void _switchToListening() {
    _focusNode.unfocus();
    _textController.clear();
    _startListening();
  }

  void _submitText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _focusNode.unfocus();
    _sendToAi(text);
  }

  Future<void> _sendToAi(String question) async {
    _stopListening();
    setState(() {
      _mode = _SheetMode.answering;
      _isAiLoading = true;
      _aiResponse = '';
      _recognizedText = question;
    });

    try {
      final billSummary = _buildBillContext();
      final prompt =
          '''你是一个贴心的个人财务助理。用户问了一个关于账单的问题，请根据以下账单数据回答。
注意：「花钱」「消费」「花的钱」都是指【支出】，不要把【收入】算进去。
语气亲和自然，像朋友聊天一样，不要用"您"，直接说"你"。回答简洁明了。

账单数据：
$billSummary

用户问题：$question''';

      await for (final token in _aiService.chatStream(prompt)) {
        if (!mounted) return;
        setState(() {
          _aiResponse += token;
          _isAiLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResponse = '抱歉，出了点问题，请稍后再试。';
          _isAiLoading = false;
        });
      }
    }
  }

  String _buildBillContext() {
    final allBills = widget.bills
        .where((b) => b.category == MemoryCategory.bill)
        .toList();
    if (allBills.isEmpty) return '暂无账单数据';

    double totalExpense = 0, totalIncome = 0;
    final Map<String, double> categoryExpense = {};
    final Map<String, double> categoryIncome = {};
    final Map<String, int> merchantCount = {};
    final Map<String, double> dailyExpense = {};
    final Map<String, double> dailyIncome = {};
    final List<String> expenseBills = [];
    final List<String> incomeBills = [];

    for (final bill in allBills) {
      final v =
          double.tryParse(
            (bill.amount ?? '0').replaceAll(RegExp(r'[^\d.]'), ''),
          ) ??
          0;
      final date = bill.billTime ?? bill.createdAt;
      final dayKey = '${date.month}/${date.day}';
      final isExp = bill.isExpense ?? true;

      if (isExp) {
        totalExpense += v;
        final catName = bill.billCategory ?? '其他';
        final cat = BillExpenseCategory.fromName(catName)?.label ?? catName;
        categoryExpense[cat] = (categoryExpense[cat] ?? 0) + v;
        dailyExpense[dayKey] = (dailyExpense[dayKey] ?? 0) + v;
        if (expenseBills.length < 30) {
          expenseBills.add(
            '$dayKey ${bill.merchantName ?? cat} ¥${v.toStringAsFixed(2)}',
          );
        }
      } else {
        totalIncome += v;
        final catName = bill.billCategory ?? '其他';
        final cat = BillIncomeCategory.fromName(catName)?.label ?? catName;
        categoryIncome[cat] = (categoryIncome[cat] ?? 0) + v;
        dailyIncome[dayKey] = (dailyIncome[dayKey] ?? 0) + v;
        if (incomeBills.length < 15) {
          incomeBills.add(
            '$dayKey ${bill.merchantName ?? cat} ¥${v.toStringAsFixed(2)}',
          );
        }
      }

      final merchant = bill.merchantName;
      if (merchant != null && merchant.isNotEmpty) {
        merchantCount[merchant] = (merchantCount[merchant] ?? 0) + 1;
      }
    }

    final topExpCat =
        (categoryExpense.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(5)
            .map((e) => '${e.key}: ¥${e.value.toStringAsFixed(2)}')
            .join('\n');

    final topDailyExp =
        (dailyExpense.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(5)
            .map((e) => '${e.key}: ¥${e.value.toStringAsFixed(2)}')
            .join('\n');

    final topMerchants =
        (merchantCount.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(5)
            .map((e) => '${e.key}: ${e.value}次')
            .join('\n');

    return '''=== 支出汇总 ===
总支出：¥${totalExpense.toStringAsFixed(2)}
支出分类TOP5：
$topExpCat

每日支出TOP5（花钱最多的日子）：
$topDailyExp

支出明细（最近30笔）：
${expenseBills.join('\n')}

=== 收入汇总 ===
总收入：¥${totalIncome.toStringAsFixed(2)}
${categoryIncome.isNotEmpty ? '收入分类：\n${categoryIncome.entries.map((e) => '${e.key}: ¥${e.value.toStringAsFixed(2)}').join('\n')}' : ''}
${incomeBills.isNotEmpty ? '收入明细：\n${incomeBills.join('\n')}' : ''}

=== 其他 ===
账单总笔数：${allBills.length}笔
常去商家：${topMerchants.isEmpty ? '无' : '\n$topMerchants'}''';
  }

  @override
  void dispose() {
    if (_activeInstance == this) _activeInstance = null;
    _speech.cancel();
    _silenceTimer?.cancel();
    _glowController.dispose();
    _pulseController.dispose();
    _entranceController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final contentHeight = _mode == _SheetMode.answering
        ? screenHeight * 0.38
        : screenHeight * 0.22;
    final totalHeight = contentHeight + bottomPadding;
    // 光效从内容区上方自然溢出
    final glowHeight = totalHeight + 100;

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // 渐变光效背景 — 从底部向上自然消散，无硬边
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: glowHeight,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _BottomGlowPainter(
                        animationValue: _glowController.value,
                      ),
                    );
                  },
                ),
              ),
            ),
            // 内容区域
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: totalHeight,
              child: GestureDetector(
                onTap: () {},
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: bottomPadding > 0 ? bottomPadding : safeBottom,
                  ),
                  child: Column(
                    children: [
                      Expanded(child: _buildContent()),
                      _buildBottomBar(),
                      const SizedBox(height: 8),
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

  Widget _buildContent() {
    switch (_mode) {
      case _SheetMode.listening:
        return _buildListeningContent();
      case _SheetMode.typing:
        return _buildTypingContent();
      case _SheetMode.answering:
        return _buildAnsweringContent();
    }
  }

  Widget _buildListeningContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 文字胶囊 + 两侧按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 键盘按钮 — 从中心向左展开 + 缩放 + 渐显
            AnimatedBuilder(
              animation: _leftBtnAnim,
              builder: (context, child) {
                final t = _leftBtnAnim.value;
                return Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(80 * (1 - t), 0),
                    child: Transform.scale(
                      scale: 0.15 + 0.85 * t,
                      child: child,
                    ),
                  ),
                );
              },
              child: GestureDetector(
                onTap: _switchToTyping,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.keyboard,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 中间胶囊 — 从底部缓缓上升，结尾减速
            Flexible(
              child: AnimatedBuilder(
                animation: _capsuleAnim,
                builder: (context, child) {
                  final t = _capsuleAnim.value;
                  return Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 60 * (1 - t)),
                      child: child,
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: _recognizedText.isEmpty
                          ? Text(
                              '我在听，请说...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.6),
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : StreamingText(
                              text: _recognizedText,
                              charDuration: const Duration(milliseconds: 50),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.95),
                                height: 1.3,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 关闭按钮 — 从中心向右展开 + 缩放 + 渐显
            AnimatedBuilder(
              animation: _rightBtnAnim,
              builder: (context, child) {
                final t = _rightBtnAnim.value;
                return Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(-80 * (1 - t), 0),
                    child: Transform.scale(
                      scale: 0.15 + 0.85 * t,
                      child: child,
                    ),
                  ),
                );
              },
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.xmark,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _recognizedText.isNotEmpty ? '2秒后自动发送' : '点击结束收音',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingContent() {
    if (_aiResponse.isNotEmpty) {
      return _buildAnsweringContent();
    }
    return const SizedBox.shrink();
  }

  Widget _buildAnsweringContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户问题
            Align(
              alignment: Alignment.centerRight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.65,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      _recognizedText,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // AI 回复
            if (_isAiLoading)
              _buildThinkingDots()
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      _aiResponse,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingDots() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Row(
          children: List.generate(3, (i) {
            final t = ((_pulseController.value + i * 0.33) % 1.0);
            final alpha = 0.3 + 0.7 * ((math.sin(t * math.pi * 2) + 1) / 2);
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Opacity(
                opacity: alpha,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    if (_mode == _SheetMode.listening) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        children: [
          // 麦克风按钮 — 带背景模糊
          GestureDetector(
            onTap: _switchToListening,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.mic_fill,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 输入框 — 带背景模糊
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: '输入问题...',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.3),
                        height: 1.2,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) => _submitText(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 发送按钮
          GestureDetector(
            onTap: _submitText,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                ),
              ),
              child: const Icon(
                CupertinoIcons.arrow_up,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 逐字渐显动画组件
class StreamingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration charDuration;
  final TextAlign textAlign;

  const StreamingText({
    super.key,
    required this.text,
    this.style,
    this.charDuration = const Duration(milliseconds: 50),
    this.textAlign = TextAlign.center,
  });

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText> {
  int _displayLength = 0;
  List<double> _charOpacities = [];
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _displayLength = 0;
    _charOpacities = [];
  }

  @override
  void didUpdateWidget(StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text.length > _displayLength) {
      _startStreaming();
    }
  }

  void _startStreaming() {
    if (_isStreaming) return;
    _isStreaming = true;
    _streamNextChar();
  }

  void _streamNextChar() {
    if (!mounted) return;
    if (_displayLength < widget.text.length) {
      setState(() {
        _displayLength++;
        while (_charOpacities.length < _displayLength) {
          _charOpacities.add(0.0);
        }
        _charOpacities[_displayLength - 1] = 1.0;
      });
      Future.delayed(widget.charDuration, _streamNextChar);
    } else {
      _isStreaming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_displayLength == 0 && widget.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.text.isNotEmpty) {
          _startStreaming();
        }
      });
    }

    final displayText = widget.text.substring(
      0,
      _displayLength.clamp(0, widget.text.length),
    );

    return Text(displayText, style: widget.style, textAlign: widget.textAlign);
  }
}

class _BottomGlowPainter extends CustomPainter {
  final double animationValue;

  _BottomGlowPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final t = animationValue;

    // 底部大面积柔和渐变底色 — 从透明到微微深色
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0xFF1A1A3E).withValues(alpha: 0.4),
          const Color(0xFF0E0E2A).withValues(alpha: 0.6),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 光球 1 — 大面积蓝色，缓慢流动
    final c1 = Offset(
      size.width * (0.25 + 0.2 * math.sin(t * math.pi * 2)),
      size.height * (0.4 + 0.15 * math.cos(t * math.pi * 2)),
    );
    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF3B82F6).withValues(alpha: 0.5),
          const Color(0xFF3B82F6).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c1, radius: size.width * 0.6));
    canvas.drawCircle(c1, size.width * 0.6, p1);

    // 光球 2 — 青色偏右
    final c2 = Offset(
      size.width * (0.75 - 0.2 * math.cos(t * math.pi * 2 + 1.2)),
      size.height * (0.5 + 0.15 * math.sin(t * math.pi * 2 + 1.2)),
    );
    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF06B6D4).withValues(alpha: 0.4),
          const Color(0xFF06B6D4).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c2, radius: size.width * 0.55));
    canvas.drawCircle(c2, size.width * 0.55, p2);

    // 光球 3 — 靛蓝/紫色，居中偏下
    final c3 = Offset(
      size.width * (0.5 + 0.15 * math.sin(t * math.pi * 2 + 2.8)),
      size.height * (0.65 + 0.1 * math.cos(t * math.pi * 2 + 2.8)),
    );
    final p3 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF6366F1).withValues(alpha: 0.35),
          const Color(0xFF6366F1).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c3, radius: size.width * 0.5));
    canvas.drawCircle(c3, size.width * 0.5, p3);
  }

  @override
  bool shouldRepaint(covariant _BottomGlowPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
