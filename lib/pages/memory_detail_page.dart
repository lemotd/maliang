import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:math' as math;
import '../models/memory_item.dart';
import '../models/bill_category.dart';
import '../services/memory_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_button.dart';

class _MildBounceCurve extends Curve {
  const _MildBounceCurve();

  @override
  double transform(double t) {
    const c1 = 0.8;
    const c3 = c1 + 1;
    return 1 + c3 * math.pow(t - 1, 3) + c1 * math.pow(t - 1, 2);
  }
}

class _EditBillBottomSheet extends StatefulWidget {
  final MemoryItem memory;

  const _EditBillBottomSheet({required this.memory});

  @override
  State<_EditBillBottomSheet> createState() => _EditBillBottomSheetState();
}

class _EditBillBottomSheetState extends State<_EditBillBottomSheet> {
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late DateTime _selectedDate;
  bool _isExpense = true;
  String? _selectedCategory;
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    final amountStr = widget.memory.amount ?? '0.00';
    final cleanAmount = amountStr.replaceAll(RegExp(r'[^\d.]'), '');
    _amountController = TextEditingController(text: cleanAmount);
    _noteController = TextEditingController(text: widget.memory.note ?? '');
    _selectedDate = widget.memory.billTime ?? widget.memory.createdAt;
    _isExpense = widget.memory.isExpense ?? true;
    _selectedCategory = widget.memory.billCategory;

    // 计算选中分类所在的页面
    _calculateInitialPage();
  }

  void _calculateInitialPage() {
    final categories = _isExpense
        ? BillExpenseCategory.allMaps
        : BillIncomeCategory.allMaps;
    final billCategory = widget.memory.billCategory;
    if (billCategory != null) {
      for (int i = 0; i < categories.length; i++) {
        if (categories[i]['name'] == billCategory ||
            categories[i]['label'] == billCategory) {
          _currentPage = i ~/ 8;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pageController.jumpToPage(_currentPage);
          });
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    _noteFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String _formatDateShort(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  String _formatTimeShort(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate() async {
    _amountFocusNode.unfocus();
    _noteFocusNode.unfocus();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    _amountFocusNode.unfocus();
    _noteFocusNode.unfocus();
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (time != null) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.only(left: 14, right: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 60,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppColors.onSurfaceQuaternary(isDark),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: CupertinoSlidingSegmentedControl<bool>(
                      groupValue: _isExpense,
                      thumbColor: AppColors.containerList(isDark),
                      children: const {
                        true: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '支出',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        false: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '收入',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      },
                      onValueChanged: (value) {
                        if (value != null) {
                          // 保存当前焦点状态
                          final hasAmountFocus = _amountFocusNode.hasFocus;
                          final hasNoteFocus = _noteFocusNode.hasFocus;
                          setState(() {
                            _isExpense = value;
                          });
                          // 恢复焦点
                          if (hasAmountFocus) {
                            _amountFocusNode.requestFocus();
                          } else if (hasNoteFocus) {
                            _noteFocusNode.requestFocus();
                          }
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        final amount = _amountController.text;
                        final note = _noteController.text;
                        final isExpense = _isExpense;
                        final billCategory = _selectedCategory;
                        final createdAt = _selectedDate;

                        // 更新金额格式
                        String formattedAmount = amount;
                        if (amount.isEmpty) {
                          formattedAmount = '0.00';
                        } else {
                          final prefix = isExpense ? '-' : '+';
                          formattedAmount =
                              '$prefix${amount.replaceAll(RegExp(r'[^\d.]'), '')}';
                        }

                        // 生成新的标题
                        String newTitle = widget.memory.title;
                        if (widget.memory.category == MemoryCategory.bill) {
                          newTitle = formattedAmount;
                        }

                        // 创建更新后的 MemoryItem
                        final updatedMemory = widget.memory.copyWith(
                          title: newTitle,
                          amount: formattedAmount,
                          isExpense: isExpense,
                          billCategory: billCategory,
                          note: note,
                          billTime: createdAt,
                        );

                        // 保存到数据库
                        final memoryService = MemoryService();
                        await memoryService.updateMemory(updatedMemory);

                        // 关闭底部抽屉并返回更新后的数据
                        if (mounted) {
                          Navigator.pop(context, updatedMemory);
                        }
                      },
                      child: Text(
                        '完成',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppColors.primary(isDark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer(isDark),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // 金额输入行
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '¥',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurfaceQuaternary(isDark),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            focusNode: _amountFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}'),
                              ),
                            ],
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onSurface(isDark),
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w500,
                                color: AppColors.onSurfaceOctonary(isDark),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Divider(height: 1, color: AppColors.outline(isDark)),
                    const SizedBox(height: 4),
                    // 日期、时间、备注行
                    Row(
                      children: [
                        // 日期胶囊
                        GestureDetector(
                          onTap: _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer(isDark),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _formatDateShort(_selectedDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceQuaternary(isDark),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 时间胶囊
                        GestureDetector(
                          onTap: _selectTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer(isDark),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _formatTimeShort(_selectedDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceQuaternary(isDark),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 备注输入
                        Expanded(
                          child: TextField(
                            controller: _noteController,
                            focusNode: _noteFocusNode,
                            maxLength: 20,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.onSurface(isDark),
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '添加备注',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: AppColors.onSurfaceOctonary(isDark),
                              ),
                              contentPadding: EdgeInsets.zero,
                              counterText: '',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 分类选择器
            SizedBox(
              height: 180,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _isExpense
                    ? (BillExpenseCategory.allMaps.length / 8).ceil()
                    : (BillIncomeCategory.allMaps.length / 8).ceil(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, pageIndex) {
                  final categories = _isExpense
                      ? BillExpenseCategory.allMaps
                      : BillIncomeCategory.allMaps;
                  final startIndex = pageIndex * 8;
                  final endIndex = (startIndex + 8).clamp(0, categories.length);
                  final pageCategories = categories.sublist(
                    startIndex,
                    endIndex,
                  );

                  return GridView.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: pageCategories.map((category) {
                      final isSelected =
                          _selectedCategory == category['name'] ||
                          _selectedCategory == category['label'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategory = category['name'];
                          });
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary(isDark)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: AppColors.outline(isDark),
                                        width: 1,
                                      ),
                              ),
                              child: Icon(
                                category['icon'],
                                size: 22,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.onSurface(isDark),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              category['label'],
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? AppColors.primary(isDark)
                                    : AppColors.onSurfaceQuaternary(isDark),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
            // 页面指示器 - 始终保持空间
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _buildPageIndicators(isDark),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPageIndicators(bool isDark) {
    final pageCount = _isExpense
        ? (BillExpenseCategory.allMaps.length / 8).ceil()
        : (BillIncomeCategory.allMaps.length / 8).ceil();

    if (pageCount <= 1) {
      return [];
    }

    return List.generate(
      pageCount,
      (index) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _currentPage == index
              ? AppColors.onSurface(isDark)
              : AppColors.onSurfaceOctonary(isDark),
        ),
      ),
    );
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
  late MemoryItem _memory;
  Size? _imageSize;
  bool _isLoading = true;
  late AnimationController _controller;
  double _offset = 1.0;
  final ScrollController _scrollController = ScrollController();
  double _startDragY = 0;
  double _startOffset = 0;
  bool _isDragging = false;
  bool _isTextSelecting = false;
  double _imageDisplayHeight = 0;
  double _requiredOffset = 1.0;

  @override
  void initState() {
    super.initState();
    _memory = widget.memory;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _loadImageSize();
  }

  Future<void> _loadImageSize() async {
    if (_memory.imagePath != null) {
      final file = File(_memory.imagePath!);
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
    _isDragging = false;
    _isTextSelecting = false;
    if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  void _onDragUpdate(double y, double imageAreaHeight) {
    final deltaY = y - _startDragY;

    // 如果滑动距离很小，可能是文本选择操作
    if (!_isDragging && !_isTextSelecting) {
      if (deltaY.abs() > 10) {
        _isDragging = true;
      }
    }

    if (!_isDragging) return;

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          debugPrint('PopScope 返回数据: ${_memory.title}');
          Navigator.pop(context, _memory);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surfaceLow(isDark),
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
                    child: _buildImageArea(
                      screenWidth,
                      imageAreaHeight,
                      isDark,
                    ),
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
                behavior: HitTestBehavior.translucent,
                onPointerDown: (e) => _onDragStart(e.position.dy),
                onPointerMove: (e) =>
                    _onDragUpdate(e.position.dy, imageAreaHeight),
                onPointerUp: (_) => _onDragEnd(),
                onPointerCancel: (_) => _onDragEnd(),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh(isDark),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(borderRadius),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, -2),
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
                        const SizedBox(height: 20),
                        if (_memory.category == MemoryCategory.bill) ...[
                          // 账单标题和创建时间
                          _buildBillSummaryCard(isDark),
                          const SizedBox(height: 20),
                          _buildBillDetailInfo(isDark),
                          // 一段话总结（账单类型显示在账单详情下方）
                          if (_memory.summary != null &&
                              _memory.summary!.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildSummarySection(isDark),
                          ],
                        ] else ...[
                          _buildDetailInfo(isDark),
                        ],
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
                    ? AppColors.surfaceHigh(isDark)
                    : Colors.transparent,
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: GlassButton(
                        icon: CupertinoIcons.back,
                        onTap: () {
                          debugPrint('返回按钮点击，返回数据: ${_memory.title}');
                          Navigator.pop(context, _memory);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        child: CupertinoActivityIndicator(color: AppColors.onSurface(isDark)),
      );
    }

    if (_memory.imagePath == null) {
      _imageDisplayHeight = 60; // 图标大小
      return Container(
        color: AppColors.surfaceContainer(isDark),
        child: Center(
          child: Icon(
            _getCategoryIcon(_memory.category),
            size: 60,
            color: _memory.category.color.withOpacity(0.5),
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
            File(_memory.imagePath!),
            width: displayWidth,
            height: displayHeight,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailInfo(bool isDark) {
    final children = <Widget>[];

    // 标题和创建时间卡片
    children.add(_buildTitleCard(isDark));

    // AI 总结区域
    if (_memory.summary != null && _memory.summary!.isNotEmpty) {
      children.add(const SizedBox(height: 20));
      children.add(_buildSummarySection(isDark));
    }

    // 信息区域
    if (_memory.infoSections.isNotEmpty) {
      for (var i = 0; i < _memory.infoSections.length; i++) {
        children.add(const SizedBox(height: 24));
        children.add(_buildInfoSection(_memory.infoSections[i], isDark));
      }
    } else if (_memory.category != MemoryCategory.note) {
      // 兼容旧数据：如果没有 infoSections，使用旧的显示方式（随手记类型不需要）
      children.add(const SizedBox(height: 24));
      children.add(_buildLegacyDetailInfo(isDark));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildTitleCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _memory.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatTime(_memory.createdAt)} · ${_memory.category.label}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceQuaternary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.primary(isDark),
              ),
              const SizedBox(width: 8),
              Text(
                'AI 总结',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _memory.summary!,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: AppColors.onSurface(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(InfoSection section, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 小标题
          Text(
            section.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface(isDark),
            ),
          ),
          const SizedBox(height: 6),
          // 信息项列表
          ...section.items.map((item) => _buildInfoItem(item, isDark)),
        ],
      ),
    );
  }

  Widget _buildInfoItem(InfoItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.onSurfaceQuaternary(isDark),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              item.value,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.onSurface(isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyDetailInfo(bool isDark) {
    final details = <Widget>[];

    details.add(
      _buildInfoRow(
        '分类',
        _memory.category.label,
        isDark,
        icon: _getCategoryIcon(_memory.category),
        iconColor: _memory.category.color,
      ),
    );

    details.add(_buildInfoRow('时间', _formatTime(_memory.createdAt), isDark));

    switch (_memory.category) {
      case MemoryCategory.pickupCode:
        if (_memory.shopName != null && _memory.shopName!.isNotEmpty) {
          details.add(_buildInfoRow('店铺', _memory.shopName!, isDark));
        }
        if (_memory.pickupCode != null && _memory.pickupCode!.isNotEmpty) {
          details.add(_buildInfoRow('取餐码', _memory.pickupCode!, isDark));
        }
        if (_memory.dishName != null && _memory.dishName!.isNotEmpty) {
          details.add(_buildInfoRow('餐品', _memory.dishName!, isDark));
        }
        break;
      case MemoryCategory.packageCode:
        if (_memory.expressCompany != null &&
            _memory.expressCompany!.isNotEmpty) {
          details.add(_buildInfoRow('快递', _memory.expressCompany!, isDark));
        }
        if (_memory.pickupCode != null && _memory.pickupCode!.isNotEmpty) {
          details.add(_buildInfoRow('取件码', _memory.pickupCode!, isDark));
        }
        if (_memory.pickupAddress != null &&
            _memory.pickupAddress!.isNotEmpty) {
          details.add(_buildInfoRow('地址', _memory.pickupAddress!, isDark));
        }
        if (_memory.productType != null && _memory.productType!.isNotEmpty) {
          details.add(_buildInfoRow('物品', _memory.productType!, isDark));
        }
        if (_memory.trackingNumber != null &&
            _memory.trackingNumber!.isNotEmpty) {
          details.add(_buildInfoRow('单号', _memory.trackingNumber!, isDark));
        }
        break;
      case MemoryCategory.bill:
        if (_memory.amount != null && _memory.amount!.isNotEmpty) {
          details.add(_buildInfoRow('金额', _memory.amount!, isDark));
        }
        if (_memory.paymentMethod != null &&
            _memory.paymentMethod!.isNotEmpty) {
          details.add(_buildInfoRow('支付方式', _memory.paymentMethod!, isDark));
        }
        if (_memory.merchantName != null && _memory.merchantName!.isNotEmpty) {
          details.add(_buildInfoRow('商户', _memory.merchantName!, isDark));
        }
        break;
      case MemoryCategory.note:
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            color: AppColors.outline(isDark),
          ),
        );
      }
    }
    return result;
  }

  Widget _buildBillSummaryCard(bool isDark) {
    final summary = _memory.summary ?? _memory.title;
    final createdAt = _formatTime(_memory.createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$createdAt · ${_memory.category.label}',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.onSurfaceQuaternary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillDetailInfo(bool isDark) {
    // 解析金额
    final amountStr = _memory.amount ?? '0.00';
    final amount =
        double.tryParse(amountStr.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    final isExpense = _memory.isExpense ?? true;

    // 格式化金额显示
    final formattedAmount =
        '${isExpense ? '-' : '+'}¥${amount.toStringAsFixed(2)}';
    final amountColor = AppColors.onSurface(isDark);

    // 获取账单分类
    final billCategoryName = _memory.billCategory ?? '其他';
    IconData categoryIcon = Icons.more_horiz_outlined;
    String categoryLabel = billCategoryName;

    // 使用枚举查找分类
    if (isExpense) {
      final category = BillExpenseCategory.fromName(billCategoryName);
      if (category != null) {
        categoryIcon = category.icon;
        categoryLabel = category.label;
      }
    } else {
      final category = BillIncomeCategory.fromName(billCategoryName);
      if (category != null) {
        categoryIcon = category.icon;
        categoryLabel = category.label;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary(isDark).withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary(isDark).withOpacity(0.1),
          width: 0.6,
        ),
      ),
      child: Column(
        children: [
          // 顶部：标题和编辑按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '记账',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface(isDark),
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minSize: 28,
                onPressed: () {
                  _showEditBillBottomSheet();
                },
                child: Icon(
                  CupertinoIcons.pencil,
                  size: 18,
                  color: AppColors.primary(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 金额显示
          Text(
            formattedAmount,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w500,
              color: amountColor,
            ),
          ),
          const SizedBox(height: 4),
          // 分类显示
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(categoryIcon, size: 18, color: AppColors.onSurface(isDark)),
              const SizedBox(width: 6),
              Text(
                categoryLabel,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.onSurface(isDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 分割线
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: AppColors.outline(isDark),
          ),
          const SizedBox(height: 16),
          // 详细信息
          Column(
            children: [
              _buildBillInfoRow('类型', isExpense ? '支出' : '收入', isDark),
              const SizedBox(height: 12),
              _buildBillInfoRow(
                '时间',
                _formatTime(_memory.billTime ?? _memory.createdAt),
                isDark,
              ),
              if (_memory.note != null && _memory.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildBillInfoRow('备注', _memory.note!, isDark, maxLines: 2),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillInfoRow(
    String label,
    String value,
    bool isDark, {
    IconData? icon,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.onSurfaceQuaternary(isDark),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.primary(isDark)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  value.isEmpty ? '-' : value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.onSurface(isDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditBillBottomSheet() async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _EditBillBottomSheet(memory: _memory),
      ),
    );

    debugPrint('底部抽屉返回数据: $result');
    if (result != null && result is MemoryItem) {
      debugPrint('更新 _memory: ${result.title}');
      setState(() {
        _memory = result;
      });
    }
  }

  Widget _buildInfoRow(
    String label,
    String value,
    bool isDark, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: iconColor ?? AppColors.onSurfaceQuaternary(isDark),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.onSurface(isDark),
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
