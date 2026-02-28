import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import '../services/config_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _configService = ConfigService();
  final _apiAddressController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _apiAddressController.addListener(_onApiAddressChanged);
    _apiKeyController.addListener(_onApiKeyChanged);
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

  void _onApiAddressChanged() {
    _autoSave();
  }

  void _onApiKeyChanged() {
    _autoSave();
  }

  void _autoSave() {
    if (_isLoading || _isSaving) return;
    _isSaving = true;
    Future.delayed(const Duration(milliseconds: 500), () async {
      await _configService.setApiAddress(_apiAddressController.text);
      await _configService.setApiKey(_apiKeyController.text);
      _isSaving = false;
    });
  }

  @override
  void dispose() {
    _apiAddressController.removeListener(_onApiAddressChanged);
    _apiKeyController.removeListener(_onApiKeyChanged);
    _apiAddressController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    children: [
                      const SizedBox(height: 20),
                      _buildSection(
                        title: 'AI 配置',
                        children: [
                          _buildInputField(
                            title: 'API地址',
                            controller: _apiAddressController,
                            placeholder: '请输入API地址',
                          ),
                          _buildDivider(),
                          _buildInputField(
                            title: 'API密钥',
                            controller: _apiKeyController,
                            placeholder: '请输入API密钥',
                            obscureText: true,
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: _BackButton(onTap: () => Navigator.pop(context)),
              ),
              const Positioned(
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
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String title,
    required TextEditingController controller,
    required String placeholder,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFC7C7CC),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
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
