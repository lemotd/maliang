import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:ui';
import '../services/config_service.dart';
import '../services/ai_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _configService = ConfigService();
  final _aiService = AiService();
  final _apiAddressController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final apiAddress = await _configService.getApiAddress();
    final apiKey = await _configService.getApiKey();
    setState(() {
      _apiAddressController.text = apiAddress;
      _apiKeyController.text = apiKey;
      _isLoading = false;
    });
  }

  Future<void> _saveAndValidate() async {
    if (_isSaving) return;

    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showToast('请输入 API Key');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 先保存配置
      await _configService.setApiAddress(_apiAddressController.text.trim());
      await _configService.setApiKey(apiKey);

      // 验证 API Key 是否可用
      final result = await _aiService.chat('你好', systemPrompt: '请回复"OK"');

      if (mounted) {
        if (result != null && result.isNotEmpty) {
          _showToast('API Key 运行正常');
        } else {
          _showToast('API Key 异常，请重新输入');
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast('API Key 异常，请重新输入');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _apiAddressController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      children: [
                        _buildInputField(
                          context: context,
                          title: 'API地址',
                          controller: _apiAddressController,
                          placeholder: '请输入API地址',
                        ),
                        _buildInputField(
                          context: context,
                          title: 'API Key',
                          controller: _apiKeyController,
                          placeholder: '请输入API Key',
                          obscureText: _obscureApiKey,
                          suffixIcon: GestureDetector(
                            onTap: () {
                              setState(() {
                                _obscureApiKey = !_obscureApiKey;
                              });
                            },
                            child: Icon(
                              _obscureApiKey
                                  ? CupertinoIcons.eye
                                  : CupertinoIcons.eye_slash,
                              color: const Color(0xFF8E8E93),
                              size: 20,
                            ),
                          ),
                        ),
                        // 保存按钮
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveAndValidate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007AFF),
                                disabledBackgroundColor: const Color(
                                  0xFF007AFF,
                                ).withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      '保存',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildApiKeyGuide(context),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 52,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _BackButton(onTap: () => Navigator.pop(context)),
          ),
          Positioned(
            left: 60,
            right: 60,
            top: 0,
            child: SizedBox(
              height: 52,
              child: Center(
                child: Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    final context = this.context;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required BuildContext context,
    required String title,
    required TextEditingController controller,
    required String placeholder,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A),
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: const TextStyle(
                fontSize: 16,
                color: Color(0xFF8E8E93),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF38383A)
                      : const Color(0xFFE5E5EA),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark
                      ? const Color(0xFF38383A)
                      : const Color(0xFFE5E5EA),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF007AFF),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              isDense: true,
              filled: true,
              fillColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              suffixIcon: suffixIcon,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 102),
      height: 0.5,
      color: const Color(0xFFE5E5EA),
    );
  }

  Widget _buildApiKeyGuide(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.info_circle,
                size: 18,
                color: Color(0xFF007AFF),
              ),
              const SizedBox(width: 8),
              Text(
                'API Key 配置说明',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFFFFFFF)
                      : const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '1. 访问智谱AI开放平台获取 API Key',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(
                'https://bigmodel.cn/usercenter/proj-mgmt/apikeys',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'https://bigmodel.cn/usercenter/proj-mgmt/apikeys',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF007AFF),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF007AFF),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.arrow_up_right,
                    size: 16,
                    color: Color(0xFF007AFF),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '2. 登录后创建项目，在 API Key 管理页面获取密钥',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '3. 将 API Key 粘贴到上方输入框中保存',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _resetController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _brightnessAnimation;

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isInBounds = true;
  static const double _boundsRadius = 30;

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
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.15), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.18), weight: 15),
        TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.15), weight: 15),
      ],
    ).animate(CurvedAnimation(parent: _pressController, curve: Curves.easeOut));
    _brightnessAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 60),
        TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.65), weight: 20),
        TweenSequenceItem(tween: Tween(begin: 0.65, end: 0.6), weight: 20),
      ],
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
      widget.onTap();
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
    return SizedBox(
      height: 52,
      width: 60,
      child: Center(
        child: GestureDetector(
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
                  final anchorY = dy.abs() > 0.1
                      ? -dy.sign * verticalWeight
                      : 0.0;
                  anchorAlignment = Alignment(anchorX, anchorY);
                }
              }

              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform(
                  transform: Matrix4.identity()..scale(scaleX, scaleY),
                  alignment: anchorAlignment,
                  child: Opacity(
                    opacity: _brightnessAnimation.value,
                    child: _buildGlassButton(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.6),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 0.5,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 2,
                  left: 6,
                  right: 6,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.6),
                          Colors.white.withOpacity(0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const Center(
                  child: Icon(
                    CupertinoIcons.chevron_left,
                    color: Color(0xFF1A1A1A),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
