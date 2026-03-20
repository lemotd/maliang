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

  // 智谱
  final _apiAddressController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _apiAddressFocusNode = FocusNode();
  final _apiKeyFocusNode = FocusNode();

  // 自定义
  final _customApiAddressController = TextEditingController();
  final _customApiKeyController = TextEditingController();
  final _customTextModelController = TextEditingController();
  final _customVisionModelController = TextEditingController();
  final _customApiAddressFocusNode = FocusNode();
  final _customApiKeyFocusNode = FocusNode();
  final _customTextModelFocusNode = FocusNode();
  final _customVisionModelFocusNode = FocusNode();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _obscureApiKey = true;
  bool _obscureCustomApiKey = true;
  bool _isButtonPressed = false;
  bool _isCardFocused = false;
  bool _isCustomCardFocused = false;
  bool _isGuidePressed = false;
  double _scrollOffset = 0;
  int _tabIndex = 0; // 0 = 智谱, 1 = 自定义

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _apiAddressFocusNode.addListener(_onZhipuFocusChange);
    _apiKeyFocusNode.addListener(_onZhipuFocusChange);
    _customApiAddressFocusNode.addListener(_onCustomFocusChange);
    _customApiKeyFocusNode.addListener(_onCustomFocusChange);
    _customTextModelFocusNode.addListener(_onCustomFocusChange);
    _customVisionModelFocusNode.addListener(_onCustomFocusChange);
  }

  void _onZhipuFocusChange() {
    setState(() {
      _isCardFocused =
          _apiAddressFocusNode.hasFocus || _apiKeyFocusNode.hasFocus;
    });
  }

  void _onCustomFocusChange() {
    setState(() {
      _isCustomCardFocused =
          _customApiAddressFocusNode.hasFocus ||
          _customApiKeyFocusNode.hasFocus ||
          _customTextModelFocusNode.hasFocus ||
          _customVisionModelFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _apiAddressController.dispose();
    _apiKeyController.dispose();
    _apiAddressFocusNode.removeListener(_onZhipuFocusChange);
    _apiAddressFocusNode.dispose();
    _apiKeyFocusNode.removeListener(_onZhipuFocusChange);
    _apiKeyFocusNode.dispose();
    _customApiAddressController.dispose();
    _customApiKeyController.dispose();
    _customTextModelController.dispose();
    _customVisionModelController.dispose();
    _customApiAddressFocusNode.removeListener(_onCustomFocusChange);
    _customApiAddressFocusNode.dispose();
    _customApiKeyFocusNode.removeListener(_onCustomFocusChange);
    _customApiKeyFocusNode.dispose();
    _customTextModelFocusNode.removeListener(_onCustomFocusChange);
    _customTextModelFocusNode.dispose();
    _customVisionModelFocusNode.removeListener(_onCustomFocusChange);
    _customVisionModelFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final apiAddress = await _configService.getApiAddress();
    final apiKey = await _configService.getApiKey();
    final modelType = await _configService.getModelType();
    final customApiAddress = await _configService.getCustomApiAddress();
    final customApiKey = await _configService.getCustomApiKey();
    final customTextModel = await _configService.getCustomTextModel();
    final customVisionModel = await _configService.getCustomVisionModel();
    setState(() {
      _apiAddressController.text = apiAddress;
      _apiKeyController.text = apiKey;
      _tabIndex = modelType == 'custom' ? 1 : 0;
      _customApiAddressController.text = customApiAddress;
      if (customApiKey.isNotEmpty) _customApiKeyController.text = customApiKey;
      _customTextModelController.text = customTextModel;
      _customVisionModelController.text = customVisionModel;
      _isLoading = false;
    });
  }

  Future<void> _saveZhipu() async {
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
      await _configService.setModelType('zhipu');
      final result = await _aiService.chat('你好', systemPrompt: '请回复"OK"');
      if (mounted) {
        _showToast(
          result != null && result.isNotEmpty
              ? 'API Key 运行正常'
              : 'API Key 异常，请重新输入',
        );
      }
    } catch (e) {
      if (mounted) _showToast('API Key 异常，请重新输入');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveCustom() async {
    if (_isSaving) return;
    final apiAddress = _customApiAddressController.text.trim();
    final apiKey = _customApiKeyController.text.trim();
    final textModel = _customTextModelController.text.trim();
    final visionModel = _customVisionModelController.text.trim();
    if (apiAddress.isEmpty) {
      _showToast('请输入 API 地址');
      return;
    }
    if (apiKey.isEmpty) {
      _showToast('请输入 API Key');
      return;
    }
    if (textModel.isEmpty) {
      _showToast('请输入文本模型名称');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _configService.setCustomApiAddress(apiAddress);
      await _configService.setCustomApiKey(apiKey);
      await _configService.setCustomTextModel(textModel);
      await _configService.setCustomVisionModel(
        visionModel.isNotEmpty ? visionModel : textModel,
      );
      await _configService.setModelType('custom');
      final result = await _aiService.chat('你好', systemPrompt: '请回复"OK"');
      if (mounted) {
        _showToast(
          result != null && result.isNotEmpty ? '自定义模型运行正常' : '模型连接异常，请检查配置',
        );
      }
    } catch (e) {
      if (mounted) _showToast('模型连接异常，请检查配置');
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
            // Tab 导航 — 滑动指示器
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final tabWidth = (totalWidth - 6) / 2; // 减去左右 margin
                  final indicatorLeft = 3.0 + _tabIndex * tabWidth;

                  return Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer(isDark),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Stack(
                      children: [
                        // 滑动背景指示器
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          left: indicatorLeft,
                          top: 3,
                          bottom: 3,
                          width: tabWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.onSurfaceButtonSelect(isDark),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                        // 前景 tab 文字
                        Row(
                          children: [
                            _buildTab(isDark, '智谱模型', 0),
                            _buildTab(isDark, '自定义模型', 1),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 分割线（收缩时显示在导航器下方）
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              height: isCollapsed ? 0.6 : 0,
              child: Container(height: 0.6, color: const Color(0x0F000000)),
            ),
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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _tabIndex == 0
                              ? _buildZhipuContent(isDark)
                              : _buildCustomContent(isDark),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(bool isDark, String label, int index) {
    final selected = _tabIndex == index;
    return Expanded(
      child: _TabButton(
        label: label,
        selected: selected,
        isDark: isDark,
        onTap: () => setState(() => _tabIndex = index),
      ),
    );
  }

  Widget _buildZhipuContent(bool isDark) {
    return ListView(
      key: const ValueKey('zhipu'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _buildZhipuApiCard(isDark),
        _buildSaveButton(isDark, _saveZhipu),
        const SizedBox(height: 12),
        _buildApiKeyGuide(isDark),
        const SizedBox(height: 40),
        // 补偿 AppBar 收缩高度差，防止弹回
        const SizedBox(height: 54),
      ],
    );
  }

  Widget _buildCustomContent(bool isDark) {
    return ListView(
      key: const ValueKey('custom'),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      children: [
        _buildCustomApiCard(isDark),
        _buildSaveButton(isDark, _saveCustom),
        const SizedBox(height: 40),
        // 补偿 AppBar 收缩高度差，防止弹回
        const SizedBox(height: 54),
      ],
    );
  }

  Widget _buildSaveButton(bool isDark, VoidCallback onSave) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isButtonPressed = true),
        onTapUp: (_) {},
        onTapCancel: () => setState(() => _isButtonPressed = false),
        onTap: () async {
          setState(() => _isButtonPressed = true);
          await Future.delayed(const Duration(milliseconds: 80));
          if (mounted) setState(() => _isButtonPressed = false);
          if (!_isSaving) onSave();
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
                  ? AppColors.primary(isDark).withValues(alpha: 0.5)
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    );
  }

  Widget _buildZhipuApiCard(bool isDark) {
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
          _buildInputField(
            isDark: isDark,
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
          _buildInputField(
            isDark: isDark,
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

  Widget _buildCustomApiCard(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: smoothRadius(20),
        border: _isCustomCardFocused
            ? Border.all(color: AppColors.primary(isDark), width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInputField(
            isDark: isDark,
            title: 'API 地址',
            controller: _customApiAddressController,
            placeholder: '请输入API地址',
            focusNode: _customApiAddressFocusNode,
          ),
          _buildDivider(isDark),
          _buildInputField(
            isDark: isDark,
            title: 'API Key',
            controller: _customApiKeyController,
            placeholder: '请输入API Key',
            obscureText: _obscureCustomApiKey,
            focusNode: _customApiKeyFocusNode,
            suffixIcon: GestureDetector(
              onTap: () =>
                  setState(() => _obscureCustomApiKey = !_obscureCustomApiKey),
              child: Icon(
                _obscureCustomApiKey ? Icons.visibility_off : Icons.visibility,
                size: 16,
                color: AppColors.onSurfaceQuaternary(isDark),
              ),
            ),
          ),
          _buildDivider(isDark),
          _buildInputField(
            isDark: isDark,
            title: '文本模型名称',
            controller: _customTextModelController,
            placeholder: '如 gpt-4o、deepseek-chat',
            focusNode: _customTextModelFocusNode,
          ),
          _buildDivider(isDark),
          _buildInputField(
            isDark: isDark,
            title: '视觉模型名称（选填）',
            controller: _customVisionModelController,
            placeholder: '留空则使用文本模型',
            focusNode: _customVisionModelFocusNode,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      height: 0.6,
      color: AppColors.outline(isDark),
    );
  }

  Widget _buildInputField({
    required bool isDark,
    required String title,
    required TextEditingController controller,
    required String placeholder,
    required FocusNode focusNode,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
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
      ],
    );
  }

  Widget _buildApiKeyGuide(bool isDark) {
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
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'https://bigmodel.cn/usercenter/proj-mgmt/apikeys',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF007AFF),
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

class _TabButton extends StatefulWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton> {
  bool _pressed = false;

  void _handleTap() async {
    setState(() => _pressed = true);
    await Future.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() => _pressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {},
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          margin: const EdgeInsets.all(3),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 14,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
              color: AppColors.onSurface(widget.isDark),
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}
