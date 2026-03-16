import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/config_service.dart';
import '../services/ai_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_button.dart';
import '../utils/scroll_edge_haptic.dart';
import '../utils/smooth_radius.dart';

class AiModelSettingsPage extends StatefulWidget {
  const AiModelSettingsPage({super.key});

  @override
  State<AiModelSettingsPage> createState() => _AiModelSettingsPageState();
}

class _AiModelSettingsPageState extends State<AiModelSettingsPage> {
  final _configService = ConfigService();
  final _aiService = AiService();
  final _apiAddressController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiAddressFocusNode = FocusNode();
  final _apiKeyFocusNode = FocusNode();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureApiKey = true;
  bool _isButtonPressed = false;
  bool _isCardFocused = false;
  bool _isGuidePressed = false;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _apiAddressFocusNode.addListener(_onFocusChange);
    _apiKeyFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      _isCardFocused =
          _apiAddressFocusNode.hasFocus || _apiKeyFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _apiAddressController.dispose();
    _apiKeyController.dispose();
    _apiAddressFocusNode.removeListener(_onFocusChange);
    _apiAddressFocusNode.dispose();
    _apiKeyFocusNode.removeListener(_onFocusChange);
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final apiAddress = await _configService.getApiAddress();
    final apiKey = await _configService.getApiKey();
    setState(() {
      _apiAddressController.text = apiAddress;
      if (apiKey.isNotEmpty) {
        _apiKeyController.text = apiKey;
      }
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

    setState(() => _isSaving = true);

    try {
      await _configService.setApiAddress(_apiAddressController.text.trim());
      await _configService.setApiKey(apiKey);

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
      if (mounted) setState(() => _isSaving = false);
    }
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
        child: Column(
          children: [
            _buildAppBar(context, isCollapsed),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ScrollEdgeHaptic(
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
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          children: [
                            _buildApiCard(context),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: GestureDetector(
                                onTapDown: (_) =>
                                    setState(() => _isButtonPressed = true),
                                onTapUp: (_) {},
                                onTapCancel: () =>
                                    setState(() => _isButtonPressed = false),
                                onTap: () async {
                                  setState(() => _isButtonPressed = true);
                                  await Future.delayed(
                                    const Duration(milliseconds: 80),
                                  );
                                  if (mounted) {
                                    setState(() => _isButtonPressed = false);
                                  }
                                  if (!_isSaving) _saveAndValidate();
                                },
                                child: AnimatedScale(
                                  scale: _isButtonPressed ? 0.95 : 1.0,
                                  duration: const Duration(milliseconds: 150),
                                  curve: Curves.easeOut,
                                  child: Container(
                                    width: double.infinity,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _isSaving
                                          ? AppColors.primary(
                                              isDark,
                                            ).withValues(alpha: 0.5)
                                          : AppColors.primary(isDark),
                                      borderRadius: smoothRadius(100),
                                    ),
                                    child: Center(
                                      child: _isSaving
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
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
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildApiKeyGuide(context),
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
                    'AI 大模型设置',
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
                      'AI 大模型设置',
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

  Widget _buildApiCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: smoothRadius(20),
        border: _isCardFocused
            ? Border.all(color: AppColors.primary(isDark), width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputFieldContent(
            context: context,
            title: 'API 地址',
            controller: _apiAddressController,
            placeholder: '请输入API地址',
            focusNode: _apiAddressFocusNode,
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            height: 0.6,
            color: AppColors.outline(isDark),
          ),
          _buildInputFieldContent(
            context: context,
            title: 'API Key',
            controller: _apiKeyController,
            placeholder: '请输入API Key',
            obscureText: _obscureApiKey,
            focusNode: _apiKeyFocusNode,
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscureApiKey = !_obscureApiKey),
              child: Icon(
                _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                size: 16,
                color: AppColors.onSurfaceQuaternary(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputFieldContent({
    required BuildContext context,
    required String title,
    required TextEditingController controller,
    required String placeholder,
    required FocusNode focusNode,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurfaceQuaternary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            style: TextStyle(fontSize: 16, color: AppColors.onSurface(isDark)),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(
                fontSize: 16,
                color: AppColors.onSurfaceOctonary(isDark),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              suffixIcon: suffixIcon,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyGuide(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isGuidePressed = true),
      onTapUp: (_) {},
      onTapCancel: () => setState(() => _isGuidePressed = false),
      onTap: () async {
        setState(() => _isGuidePressed = true);
        await Future.delayed(const Duration(milliseconds: 80));
        if (mounted) setState(() => _isGuidePressed = false);
      },
      child: AnimatedScale(
        scale: _isGuidePressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
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
                  const Icon(
                    CupertinoIcons.info_circle,
                    size: 18,
                    color: Color(0xFF007AFF),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'API Key 配置说明',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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
                  color: isDark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF666666),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF2F2F7),
                    borderRadius: smoothRadius(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'https://bigmodel.cn/usercenter/proj-mgmt/apikeys',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF007AFF),
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFF007AFF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
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
                  color: isDark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '3. 将 API Key 粘贴到上方输入框中保存',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
