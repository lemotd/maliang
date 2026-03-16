import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:gal/gal.dart';

class ImageViewerPage extends StatefulWidget {
  final String imagePath;
  final String heroTag;
  final Animation<double> animation;

  const ImageViewerPage({
    super.key,
    required this.imagePath,
    required this.heroTag,
    required this.animation,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  bool _isSaving = false;
  final TransformationController _transformCtrl = TransformationController();
  double _dragOffset = 0.0;
  bool _isDragging = false;
  double? _dismissOpacity;
  int _pointerCount = 0;

  bool get _isZoomed {
    final scale = _transformCtrl.value.getMaxScaleOnAxis();
    return scale > 1.01;
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await Gal.putImage(widget.imagePath);
      HapticFeedback.mediumImpact();
      if (mounted) _showToast('已保存到相册');
    } catch (e) {
      if (mounted) {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          final granted = await Gal.requestAccess();
          if (granted) {
            try {
              await Gal.putImage(widget.imagePath);
              HapticFeedback.mediumImpact();
              if (mounted) _showToast('已保存到相册');
            } catch (_) {
              if (mounted) _showToast('保存失败');
            }
          } else {
            if (mounted) _showToast('需要相册权限');
          }
        } else {
          _showToast('保存失败');
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 60,
          right: 60,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dragProgress = (_dragOffset / 300).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final double bgOpacity;
        if (_dismissOpacity != null) {
          bgOpacity = widget.animation.value * _dismissOpacity!;
        } else {
          bgOpacity = widget.animation.value * (1.0 - dragProgress);
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Listener(
            onPointerDown: (_) => _pointerCount++,
            onPointerUp: (_) {
              _pointerCount--;
              // 单指抬起时结束拖拽
              if (_isDragging && _pointerCount <= 0) {
                _pointerCount = 0;
                if (_dragOffset > 100) {
                  final dp = (_dragOffset / 300).clamp(0.0, 1.0);
                  _dismissOpacity = 1.0 - dp;
                  Navigator.pop(context);
                } else {
                  setState(() {
                    _dragOffset = 0;
                    _isDragging = false;
                  });
                }
              }
            },
            onPointerCancel: (_) {
              _pointerCount = (_pointerCount - 1).clamp(0, 99);
            },
            onPointerMove: (event) {
              // 只在单指 + 未缩放时处理下滑
              if (_pointerCount != 1 || _isZoomed) {
                if (_isDragging) {
                  // 第二根手指按下，取消拖拽
                  setState(() {
                    _dragOffset = 0;
                    _isDragging = false;
                  });
                }
                return;
              }
              final dy = event.delta.dy;
              if (!_isDragging) {
                // 只有明显向下滑动才开始拖拽
                if (dy > 1.5) {
                  setState(() => _isDragging = true);
                }
                return;
              }
              setState(() {
                _dragOffset = (_dragOffset + dy).clamp(0.0, double.infinity);
              });
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: Colors.black.withValues(alpha: bgOpacity)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: AnimatedContainer(
                    duration: _isDragging
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    transform: Matrix4.translationValues(0, _dragOffset, 0),
                    child: SizedBox.expand(
                      child: InteractiveViewer(
                        transformationController: _transformCtrl,
                        minScale: 1.0,
                        maxScale: 5.0,
                        child: Center(
                          child: Hero(
                            tag: widget.heroTag,
                            flightShuttleBuilder:
                                (
                                  flightContext,
                                  anim,
                                  direction,
                                  fromHeroContext,
                                  toHeroContext,
                                ) {
                                  return AnimatedBuilder(
                                    animation: anim,
                                    builder: (context, child) {
                                      final radius = 16.0 * (1.0 - anim.value);
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          radius,
                                        ),
                                        child: child,
                                      );
                                    },
                                    child: Image.file(
                                      File(widget.imagePath),
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                },
                            child: Image.file(
                              File(widget.imagePath),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  child: FadeTransition(
                    opacity: widget.animation,
                    child: Opacity(
                      opacity: _dismissOpacity != null
                          ? widget.animation.value.clamp(0.0, 1.0)
                          : (1.0 - dragProgress).clamp(0.0, 1.0),
                      child: _SaveButton(
                        isSaving: _isSaving,
                        onTap: _saveToGallery,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SaveButton extends StatefulWidget {
  final bool isSaving;
  final VoidCallback onTap;
  const _SaveButton({required this.isSaving, required this.onTap});
  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
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
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          child: widget.isSaving
              ? const CupertinoActivityIndicator(color: Colors.white)
              : const Icon(
                  CupertinoIcons.arrow_down_to_line,
                  color: Colors.white,
                  size: 20,
                ),
        ),
      ),
    );
  }
}
