import 'package:flutter/material.dart';

class AppColors {
  // 文字图标色 - Light Mode
  static const Color onSurfaceLight = Color(0xFF000000);
  static const Color onSurfaceSecondaryLight = Color(0xCC000000); // 80%
  static const Color onSurfaceTertiaryLight = Color(0x99000000); // 60%
  static const Color onSurfaceQuaternaryLight = Color(0x66000000); // 40%
  static const Color onSurfaceOctonaryLight = Color(0x4D000000); // 30%

  // 文字图标色 - Dark Mode
  static const Color onSurfaceDark = Color(0xFFFFFFFF);
  static const Color onSurfaceSecondaryDark = Color(0xCCFFFFFF); // 80%
  static const Color onSurfaceTertiaryDark = Color(0x99FFFFFF); // 60%
  static const Color onSurfaceQuaternaryDark = Color(0x66FFFFFF); // 40%
  static const Color onSurfaceOctonaryDark = Color(0x4DFFFFFF); // 30%

  // 软件主色
  static const Color primaryLight = Color(0xFF3482FF);
  static const Color primaryDark = Color(0xFF4788FF);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color onPrimaryDark = Color(0xE6FFFFFF); // 90%

  // 背景色
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF000000);
  static const Color surfaceLowLight = Color(0xFFEDEFF2);
  static const Color surfaceLowDark = Color(0xFF000000);
  static const Color surfaceHighLight = Color(0xFFFFFFFF);
  static const Color surfaceHighDark = Color(0xFF1C1C1E);
  static const Color surfacePopWindowLight = Color(0xFFEDEFF2);
  static const Color surfacePopWindowDark = Color(0xFF2C2C2E);

  // 元素色
  static const Color surfaceContainerLight = Color(0x0F000000); // 6%
  static const Color surfaceContainerDark = Color(0x1AFFFFFF); // 10%
  static const Color surfaceContainerHighLight = Color(0x1A000000); // 10%
  static const Color surfaceContainerHighDark = Color(0x24FFFFFF); // 14%
  static const Color containerListLight = Color(0xFFFFFFFF);
  static const Color containerListDark = Color(0x24FFFFFF); // 14%

  // 分割线色
  static const Color outlineLight = Color(0x1A000000); // 10%
  static const Color outlineDark = Color(0x24FFFFFF); // 14%

  // 功能色
  static const Color warningLight = Color(0xFFFA382E);
  static const Color warningDark = Color(0xFFFA4238);
  static const Color successLight = Color(0xFF1DCD3A);
  static const Color successDark = Color(0xFF28D244);
  static const Color highlightPurpleLight = Color(0xFF7767F9);
  static const Color highlightPurpleDark = Color(0xFF8370FF);
  static const Color yellowLight = Color(0xFFFF9F05);
  static const Color yellowDark = Color(0xFFFFA30F);

  // 便捷方法 - 根据 isDark 返回对应颜色
  static Color onSurface(bool isDark) =>
      isDark ? onSurfaceDark : onSurfaceLight;
  static Color onSurfaceSecondary(bool isDark) =>
      isDark ? onSurfaceSecondaryDark : onSurfaceSecondaryLight;
  static Color onSurfaceTertiary(bool isDark) =>
      isDark ? onSurfaceTertiaryDark : onSurfaceTertiaryLight;
  static Color onSurfaceQuaternary(bool isDark) =>
      isDark ? onSurfaceQuaternaryDark : onSurfaceQuaternaryLight;
  static Color onSurfaceOctonary(bool isDark) =>
      isDark ? onSurfaceOctonaryDark : onSurfaceOctonaryLight;

  static Color primary(bool isDark) =>
      isDark ? primaryDark : primaryLight;
  static Color onPrimary(bool isDark) =>
      isDark ? onPrimaryDark : onPrimaryLight;

  static Color surface(bool isDark) =>
      isDark ? surfaceDark : surfaceLight;
  static Color surfaceLow(bool isDark) =>
      isDark ? surfaceLowDark : surfaceLowLight;
  static Color surfaceHigh(bool isDark) =>
      isDark ? surfaceHighDark : surfaceHighLight;
  static Color surfacePopWindow(bool isDark) =>
      isDark ? surfacePopWindowDark : surfacePopWindowLight;

  static Color surfaceContainer(bool isDark) =>
      isDark ? surfaceContainerDark : surfaceContainerLight;
  static Color surfaceContainerHigh(bool isDark) =>
      isDark ? surfaceContainerHighDark : surfaceContainerHighLight;
  static Color containerList(bool isDark) =>
      isDark ? containerListDark : containerListLight;

  static Color outline(bool isDark) =>
      isDark ? outlineDark : outlineLight;

  static Color warning(bool isDark) =>
      isDark ? warningDark : warningLight;
  static Color success(bool isDark) =>
      isDark ? successDark : successLight;
  static Color highlightPurple(bool isDark) =>
      isDark ? highlightPurpleDark : highlightPurpleLight;
  static Color yellow(bool isDark) =>
      isDark ? yellowDark : yellowLight;

  // 从 BuildContext 获取颜色
  static Color onSurfaceContext(BuildContext context) =>
      onSurface(Theme.of(context).brightness == Brightness.dark);
  static Color onSurfaceSecondaryContext(BuildContext context) =>
      onSurfaceSecondary(Theme.of(context).brightness == Brightness.dark);
  static Color onSurfaceTertiaryContext(BuildContext context) =>
      onSurfaceTertiary(Theme.of(context).brightness == Brightness.dark);
  static Color onSurfaceQuaternaryContext(BuildContext context) =>
      onSurfaceQuaternary(Theme.of(context).brightness == Brightness.dark);
  static Color onSurfaceOctonaryContext(BuildContext context) =>
      onSurfaceOctonary(Theme.of(context).brightness == Brightness.dark);

  static Color primaryContext(BuildContext context) =>
      primary(Theme.of(context).brightness == Brightness.dark);
  static Color onPrimaryContext(BuildContext context) =>
      onPrimary(Theme.of(context).brightness == Brightness.dark);

  static Color surfaceContext(BuildContext context) =>
      surface(Theme.of(context).brightness == Brightness.dark);
  static Color surfaceLowContext(BuildContext context) =>
      surfaceLow(Theme.of(context).brightness == Brightness.dark);
  static Color surfaceHighContext(BuildContext context) =>
      surfaceHigh(Theme.of(context).brightness == Brightness.dark);
  static Color surfacePopWindowContext(BuildContext context) =>
      surfacePopWindow(Theme.of(context).brightness == Brightness.dark);

  static Color surfaceContainerContext(BuildContext context) =>
      surfaceContainer(Theme.of(context).brightness == Brightness.dark);
  static Color surfaceContainerHighContext(BuildContext context) =>
      surfaceContainerHigh(Theme.of(context).brightness == Brightness.dark);
  static Color containerListContext(BuildContext context) =>
      containerList(Theme.of(context).brightness == Brightness.dark);

  static Color outlineContext(BuildContext context) =>
      outline(Theme.of(context).brightness == Brightness.dark);

  static Color warningContext(BuildContext context) =>
      warning(Theme.of(context).brightness == Brightness.dark);
  static Color successContext(BuildContext context) =>
      success(Theme.of(context).brightness == Brightness.dark);
  static Color highlightPurpleContext(BuildContext context) =>
      highlightPurple(Theme.of(context).brightness == Brightness.dark);
  static Color yellowContext(BuildContext context) =>
      yellow(Theme.of(context).brightness == Brightness.dark);
}
