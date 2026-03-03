import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:math' as math;
import '../models/memory_item.dart';

class _MildBounceCurve extends Curve {
  const _MildBounceCurve();

  @override
  double transform(double t) {
    // 类似 easeOutBack 但回弹幅度更小
    const c1 = 0.8; // 进一步降低回弹系数
    const c3 = c1 + 1;
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
  }
}

class MemoryDetailPage extends StatefulWidget {
  final MemoryItem memory;

  const MemoryDetailPage({super.key, required this.memory});

  @override
  State<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends State<MemoryDetailPage>
    with SingleTickerProviderStateMixin {
  Size? _imageSize;
  bool _isLoading = true;
  late AnimationController _controller;
  double _offset = 1.0; // 1.0 = 默认位置, 0.0 = 上滑吸附(展开), >1.0 = 下滑吸附(显示完整图片)
  final ScrollController _scrollController = ScrollController();
  double _startDragY = 0;
  double _startOffset = 0;
  bool _isDragging = false;
  double _imageDisplayHeight = 0;
  double _requiredOffset = 1.0; // 显示完整图片所需的offset

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    if (widget.memory.imagePath != null) {
      final file = File(widget.memory.imagePath!);
      final bytes = await file.readAsBytes();
      final image = await decodeImageFromList(bytes);
      if (mounted) {
        setState(() {
          _imageSize = Size(image.width.toDouble(), image.height.toDouble());
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onDragStart(double y) {
    _startDragY = y;
    _startOffset = _offset;
    _isDragging = true;
    if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  void _onDragUpdate(double y, double imageAreaHeight) {
    if (!_isDragging) return;

    final deltaY = y - _startDragY;
    // 向上滑动 deltaY < 0，offset 减少
    // 向下滑动 deltaY > 0，offset 增加
    final deltaOffset = deltaY / imageAreaHeight;
    double newOffset = _startOffset + deltaOffset;

    // 三段式拖动范围：
    // 最小：0.0（上滑吸附）
    // 最大：_requiredOffset（下滑吸附，如果图片被遮挡）
    final maxOffset = _requiredOffset > 1.0 ? _requiredOffset : 1.0;

    // 超出反馈效果：当超出范围时，使用阻尼效果
    if (newOffset < 0) {
      // 向上超出，使用阻尼
      newOffset = -_applyDamping(-newOffset, imageAreaHeight);
    } else if (newOffset > maxOffset) {
      // 向下超出，使用阻尼
      newOffset =
          maxOffset + _applyDamping(newOffset - maxOffset, imageAreaHeight);
    }

    setState(() {
      _offset = newOffset;
    });
  }

  // 阻尼效果：超出越多，阻力越大
  double _applyDamping(double overflow, double imageAreaHeight) {
    // 使用阻尼函数实现超出反馈
    return 0.1 * overflow;
  }

  void _onDragEnd() {
    if (!_isDragging) return;
    _isDragging = false;

    // 三段式吸附逻辑：根据当前位置和滑动方向决定吸附位置
    // offset = 0.0: 上滑吸附（展开）
    // offset = 1.0: 默认态
    // offset = _requiredOffset: 下滑吸附（显示完整图片）

    final deltaOffset = _offset - _startOffset;
    final maxOffset = _requiredOffset > 1.0 ? _requiredOffset : 1.0;

    // 如果超出范围，先回弹到边界
    if (_offset < 0) {
      _animateToExpanded(haptic: false);
      return;
    }
    if (_offset > maxOffset) {
      if (_requiredOffset > 1.0) {
        _animateToOffset(_requiredOffset, haptic: false);
      } else {
        _animateToDefault(haptic: false);
      }
      return;
    }

    // 判断当前位置在哪个阶段
    final isInExpandedPhase = _startOffset < 0.5;
    final isInDefaultPhase = _startOffset >= 0.5 && _startOffset <= 1.0;
    final isInShowImagePhase = _startOffset > 1.0;

    if (deltaOffset < 0) {
      // 向上滑动
      if (isInShowImagePhase) {
        // 从下滑吸附位置上滑，回到默认态（阶段切换）
        _animateToDefault(haptic: true);
      } else if (isInDefaultPhase) {
        // 从默认态上滑，吸附到展开位置（阶段切换）
        _animateToExpanded(haptic: true);
      } else {
        // 已经在展开位置，保持（无阶段切换）
        _animateToExpanded(haptic: false);
      }
    } else if (deltaOffset > 0) {
      // 向下滑动
      if (isInExpandedPhase) {
        // 从展开位置下滑，回到默认态（阶段切换）
        _animateToDefault(haptic: true);
      } else if (isInDefaultPhase && _requiredOffset > 1.0) {
        // 从默认态下滑，图片被遮挡，吸附到显示完整图片的位置（阶段切换）
        _animateToOffset(_requiredOffset, haptic: true);
      } else {
        // 图片没有被遮挡或已经在下滑吸附位置，回到默认态（无阶段切换）
        _animateToDefault(haptic: false);
      }
    } else {
      // 没有滑动，根据当前位置吸附
      if (_offset < 0.5) {
        _animateToExpanded(haptic: false);
      } else if (_offset > _requiredOffset - 0.1 && _requiredOffset > 1.0) {
        _animateToOffset(_requiredOffset, haptic: false);
      } else {
        _animateToDefault(haptic: false);
      }
    }
  }

  void _animateToOffset(double targetOffset, {bool haptic = true}) {
    if (haptic) HapticFeedback.lightImpact();
    final start = _offset;
    final end = targetOffset;

    final animation = Tween<double>(begin: start, end: end).animate(
      CurvedAnimation(parent: _controller, curve: const _MildBounceCurve()),
    );

    animation.addListener(() {
      setState(() {
        _offset = animation.value;
      });
    });

    _controller.forward(from: 0);
  }

  void _animateToExpanded({bool haptic = true}) {
    if (haptic) HapticFeedback.lightImpact();
    final start = _offset;
    final end = 0.0;

    final animation = Tween<double>(begin: start, end: end).animate(
      CurvedAnimation(parent: _controller, curve: const _MildBounceCurve()),
    );

    animation.addListener(() {
      setState(() {
        _offset = animation.value;
      });
    });

    _controller.forward(from: 0);
  }

  void _animateToDefault({bool haptic = true}) {
    if (haptic) HapticFeedback.lightImpact();
    final start = _offset;
    final end = 1.0;

    final animation = Tween<double>(begin: start, end: end).animate(
      CurvedAnimation(parent: _controller, curve: const _MildBounceCurve()),
    );

    animation.addListener(() {
      setState(() {
        _offset = animation.value;
      });
    });

    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaTop = MediaQuery.of(context).padding.top;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    final imageAreaHeight = screenHeight * 0.3;
    final appBarHeight = 44.0 + safeAreaTop;

    // 计算显示完整图片所需的offset
    // _imageDisplayHeight 是图片实际显示高度（已包含上下边距）
    // 如果图片实际高度小于等于图片区域高度，则图片完全显示，不需要下滑吸附
    if (_imageDisplayHeight > 0 && _imageDisplayHeight > imageAreaHeight) {
      // 图片被遮挡，计算需要的offset
      _requiredOffset = _imageDisplayHeight / imageAreaHeight;
    } else {
      _requiredOffset = 1.0;
    }

    // 计算内容区位置：offset=1时在图片下方，offset=0时在顶栏下方
    final contentTop = appBarHeight + imageAreaHeight * _offset;

    // 计算圆角：offset=1时为20，offset=0时为0
    final borderRadius = 20.0 * _offset;

    // 计算图片透明度
    final imageOpacity = _offset.clamp(0.0, 1.0);

    // 计算图片向上位移：从默认态上滑时，图片略微向上移动
    // offset 从 1.0 到 0.5 时，图片向上移动
    final imageSlideUp = _offset < 1.0 ? (1.0 - _offset) * 30 : 0.0;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFF2F2F7),
      body: Stack(
        children: [
          // 图片区域
          if (imageOpacity > 0)
            Positioned(
              top: appBarHeight - imageSlideUp,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Opacity(
                  opacity: imageOpacity,
                  child: _buildImageArea(screenWidth, imageAreaHeight, isDark),
                ),
              ),
            ),
          // 内容区域
          Positioned(
            top: contentTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: Listener(
              onPointerDown: (e) => _onDragStart(e.position.dy),
              onPointerMove: (e) =>
                  _onDragUpdate(e.position.dy, imageAreaHeight),
              onPointerUp: (_) => _onDragEnd(),
              onPointerCancel: (_) => _onDragEnd(),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(borderRadius),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                      blurRadius: 24,
                      spreadRadius: 0,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: _offset < 0.5 && !_isDragging
                      ? const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        )
                      : const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: safeAreaBottom + 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 20,
                          left: 20,
                          right: 20,
                        ),
                        child: Text(
                          widget.memory.title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFFFFFFFF)
                                : const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDetailInfo(isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 顶栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: appBarHeight,
              padding: EdgeInsets.only(top: safeAreaTop),
              color: _offset < 0.5
                  ? (isDark ? const Color(0xFF1C1C1E) : Colors.white)
                  : Colors.transparent,
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Icon(
                        CupertinoIcons.back,
                        color: isDark
                            ? const Color(0xFFFFFFFF)
                            : const Color(0xFF1A1A1A),
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageArea(
    double screenWidth,
    double imageAreaHeight,
    bool isDark,
  ) {
    if (_isLoading) {
      return Center(
        child: CupertinoActivityIndicator(
          color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A),
        ),
      );
    }

    if (widget.memory.imagePath == null) {
      _imageDisplayHeight = 60; // 图标大小
      return Container(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
        child: Center(
          child: Icon(
            _getCategoryIcon(widget.memory.category),
            size: 60,
            color: widget.memory.category.color.withOpacity(0.5),
          ),
        ),
      );
    }

    // 图片宽度限制：最小50%，最大70%
    final minImageWidth = screenWidth * 0.5;
    final maxImageWidth = screenWidth * 0.7;

    // 上下边距
    const verticalMargin = 16.0;
    final availableHeight = imageAreaHeight - verticalMargin * 2;

    double displayWidth;
    double displayHeight;

    if (_imageSize != null) {
      final aspectRatio = _imageSize!.width / _imageSize!.height;

      // 先按最大宽度计算高度
      displayWidth = maxImageWidth;
      displayHeight = displayWidth / aspectRatio;

      // 如果高度超过可用高度，按高度缩放
      if (displayHeight > availableHeight) {
        displayHeight = availableHeight;
        displayWidth = displayHeight * aspectRatio;
      }

      // 确保宽度在限制范围内
      if (displayWidth > maxImageWidth) {
        displayWidth = maxImageWidth;
        displayHeight = displayWidth / aspectRatio;
      } else if (displayWidth < minImageWidth) {
        displayWidth = minImageWidth;
        displayHeight = displayWidth / aspectRatio;
      }
    } else {
      displayWidth = maxImageWidth;
      displayHeight = availableHeight;
    }

    // 更新图片显示高度
    _imageDisplayHeight = displayHeight + verticalMargin * 2;

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: verticalMargin),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            File(widget.memory.imagePath!),
            width: displayWidth,
            height: displayHeight,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailInfo(bool isDark) {
    final details = <Widget>[];

    details.add(
      _buildInfoRow(
        '分类',
        widget.memory.category.label,
        isDark,
        icon: _getCategoryIcon(widget.memory.category),
        iconColor: widget.memory.category.color,
      ),
    );

    details.add(
      _buildInfoRow('时间', _formatTime(widget.memory.createdAt), isDark),
    );

    switch (widget.memory.category) {
      case MemoryCategory.pickupCode:
        if (widget.memory.shopName != null &&
            widget.memory.shopName!.isNotEmpty) {
          details.add(_buildInfoRow('店铺', widget.memory.shopName!, isDark));
        }
        if (widget.memory.pickupCode != null &&
            widget.memory.pickupCode!.isNotEmpty) {
          details.add(_buildInfoRow('取餐码', widget.memory.pickupCode!, isDark));
        }
        if (widget.memory.dishName != null &&
            widget.memory.dishName!.isNotEmpty) {
          details.add(_buildInfoRow('餐品', widget.memory.dishName!, isDark));
        }
        break;
      case MemoryCategory.packageCode:
        if (widget.memory.expressCompany != null &&
            widget.memory.expressCompany!.isNotEmpty) {
          details.add(
            _buildInfoRow('快递', widget.memory.expressCompany!, isDark),
          );
        }
        if (widget.memory.pickupCode != null &&
            widget.memory.pickupCode!.isNotEmpty) {
          details.add(_buildInfoRow('取件码', widget.memory.pickupCode!, isDark));
        }
        if (widget.memory.pickupAddress != null &&
            widget.memory.pickupAddress!.isNotEmpty) {
          details.add(
            _buildInfoRow('地址', widget.memory.pickupAddress!, isDark),
          );
        }
        if (widget.memory.productType != null &&
            widget.memory.productType!.isNotEmpty) {
          details.add(_buildInfoRow('物品', widget.memory.productType!, isDark));
        }
        if (widget.memory.trackingNumber != null &&
            widget.memory.trackingNumber!.isNotEmpty) {
          details.add(
            _buildInfoRow('单号', widget.memory.trackingNumber!, isDark),
          );
        }
        break;
      case MemoryCategory.bill:
        if (widget.memory.amount != null && widget.memory.amount!.isNotEmpty) {
          details.add(_buildInfoRow('金额', widget.memory.amount!, isDark));
        }
        if (widget.memory.paymentMethod != null &&
            widget.memory.paymentMethod!.isNotEmpty) {
          details.add(
            _buildInfoRow('支付方式', widget.memory.paymentMethod!, isDark),
          );
        }
        if (widget.memory.merchantName != null &&
            widget.memory.merchantName!.isNotEmpty) {
          details.add(_buildInfoRow('商户', widget.memory.merchantName!, isDark));
        }
        break;
      case MemoryCategory.note:
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: _addDividers(details, isDark)),
    );
  }

  List<Widget> _addDividers(List<Widget> children, bool isDark) {
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
            color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA),
          ),
        );
      }
    }
    return result;
  }

  Widget _buildInfoRow(
    String label,
    String value,
    bool isDark, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: Color(0xFF8E8E93)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: iconColor ?? const Color(0xFF8E8E93),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark
                          ? const Color(0xFFFFFFFF)
                          : const Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.year}年${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  IconData _getCategoryIcon(MemoryCategory category) {
    switch (category) {
      case MemoryCategory.pickupCode:
        return Icons.restaurant_menu;
      case MemoryCategory.packageCode:
        return Icons.inventory_2;
      case MemoryCategory.bill:
        return Icons.receipt_long;
      case MemoryCategory.note:
        return Icons.note_alt;
    }
  }
}
