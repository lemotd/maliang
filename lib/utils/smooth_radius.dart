import 'package:figma_squircle/figma_squircle.dart';

/// 统一的平滑圆角，cornerSmoothing 0.6 接近 iOS 风格
SmoothBorderRadius smoothRadius(double radius) {
  return SmoothBorderRadius(cornerRadius: radius, cornerSmoothing: 0.6);
}

SmoothRectangleBorder smoothRectangleBorder(double radius) {
  return SmoothRectangleBorder(borderRadius: smoothRadius(radius));
}

/// 仅底部圆角的平滑边框
SmoothBorderRadius smoothRadiusBottom(double radius) {
  return SmoothBorderRadius.only(
    bottomLeft: SmoothRadius(cornerRadius: radius, cornerSmoothing: 0.6),
    bottomRight: SmoothRadius(cornerRadius: radius, cornerSmoothing: 0.6),
  );
}

/// 仅顶部圆角的平滑边框
SmoothBorderRadius smoothRadiusTop(double radius) {
  return SmoothBorderRadius.only(
    topLeft: SmoothRadius(cornerRadius: radius, cornerSmoothing: 0.6),
    topRight: SmoothRadius(cornerRadius: radius, cornerSmoothing: 0.6),
  );
}
