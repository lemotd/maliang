import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final Map<String, ImageProvider> _imageProviders = {};
  final Map<String, Size> _imageSizes = {};

  static const int _maxCacheSize = 100;

  ImageProvider? getImageProvider(String? path) {
    if (path == null || path.isEmpty) return null;

    if (_imageProviders.containsKey(path)) {
      return _imageProviders[path];
    }

    final file = File(path);
    if (!file.existsSync()) return null;

    final imageProvider = FileImage(file);
    _imageProviders[path] = imageProvider;

    if (_imageProviders.length > _maxCacheSize) {
      final firstKey = _imageProviders.keys.first;
      _imageProviders.remove(firstKey);
      _imageSizes.remove(firstKey);
    }

    return imageProvider;
  }

  Future<Size?> getImageSize(String? path) async {
    if (path == null || path.isEmpty) return null;

    if (_imageSizes.containsKey(path)) {
      return _imageSizes[path];
    }

    final imageProvider = getImageProvider(path);
    if (imageProvider == null) return null;

    try {
      final completer = Completer<Size?>();
      final stream = imageProvider.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          final size = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
          _imageSizes[path] = size;
          completer.complete(size);
          stream.removeListener(listener);
        },
        onError: (exception, stackTrace) {
          completer.complete(null);
          stream.removeListener(listener);
        },
      );
      stream.addListener(listener);
      return completer.future;
    } catch (e) {
      return null;
    }
  }

  void cacheImageSize(String path, Size size) {
    _imageSizes[path] = size;
  }

  Size? getCachedImageSize(String? path) {
    if (path == null || path.isEmpty) return null;
    return _imageSizes[path];
  }

  void clearCache() {
    _imageProviders.clear();
    _imageSizes.clear();
  }

  void removeFromCache(String? path) {
    if (path == null || path.isEmpty) return;
    _imageProviders.remove(path);
    _imageSizes.remove(path);
  }
}
