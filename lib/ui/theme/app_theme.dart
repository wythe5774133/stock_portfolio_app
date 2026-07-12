// App 主題：深淺兩套色票與 ThemeData，供使用者切換背景深淺。

import 'package:flutter/material.dart';

/// 使用者可選的主題模式。
enum AppThemeMode {
  light,
  dark,
  system,
}

/// 將主題模式轉為儲存字串。
String FormatAppThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return 'light';
    case AppThemeMode.dark:
      return 'dark';
    case AppThemeMode.system:
      return 'system';
  }
}

/// 由儲存字串還原主題模式，無法解析時跟隨系統。
AppThemeMode ParseAppThemeMode(String? raw) {
  switch (raw) {
    case 'light':
      return AppThemeMode.light;
    case 'dark':
      return AppThemeMode.dark;
    default:
      return AppThemeMode.system;
  }
}

/// 轉為 MaterialApp 用的 ThemeMode。
ThemeMode ConvertToMaterialThemeMode(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
}

/*
 * @author  Toby
 *
 * @date    2026/07/11
 *
 * @class   AppColors
 *
 * @brief   深淺兩套介面色票；widget 一律以 AppColors.Of(context) 取色，
 *          不得寫死顏色，確保兩種模式都可讀。
 */
class AppColors {
  final Color page_background; // 頁面底色
  final Color card_background; // 卡片底色
  final Color card_border; // 卡片邊框
  final Color subtle_background; // 卡片內的次要區塊底色（交易明細等）
  final Color divider; // 列表分隔線
  final Color text_primary; // 主要文字
  final Color text_secondary; // 次要文字（欄位標題等）
  final Color text_muted; // 弱化文字（提示、來源標示）
  final Color primary_button_background; // 主要按鈕底色
  final Color primary_button_foreground; // 主要按鈕文字

  const AppColors({
    required this.page_background,
    required this.card_background,
    required this.card_border,
    required this.subtle_background,
    required this.divider,
    required this.text_primary,
    required this.text_secondary,
    required this.text_muted,
    required this.primary_button_background,
    required this.primary_button_foreground,
  });

  static const AppColors LIGHT = AppColors(
    page_background: Color(0xFFF4F5F7),
    card_background: Colors.white,
    card_border: Color(0xFFE8EAEE),
    subtle_background: Color(0xFFF8F9FB),
    divider: Color(0xFFF0F1F4),
    text_primary: Color(0xFF111827),
    text_secondary: Color(0xFF6B7280),
    text_muted: Color(0xFF9CA3AF),
    primary_button_background: Color(0xFF111827),
    primary_button_foreground: Colors.white,
  );

  static const AppColors DARK = AppColors(
    page_background: Color(0xFF101216),
    card_background: Color(0xFF1A1D23),
    card_border: Color(0xFF2A2E36),
    subtle_background: Color(0xFF22262E),
    divider: Color(0xFF262A32),
    text_primary: Color(0xFFF3F4F6),
    text_secondary: Color(0xFF9CA3AF),
    text_muted: Color(0xFF6B7280),
    primary_button_background: Color(0xFFE5E7EB),
    primary_button_foreground: Color(0xFF111827),
  );

  /// 依目前主題亮度取得對應色票。
  static AppColors Of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? DARK : LIGHT;
  }
}

/// 建立指定亮度的 ThemeData（淺色與深色共用同一套結構）。
ThemeData BuildAppTheme(Brightness brightness) {
  final bool is_dark = brightness == Brightness.dark;
  final AppColors colors = is_dark ? AppColors.DARK : AppColors.LIGHT;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F6DF5),
      brightness: brightness,
      surface: colors.card_background,
    ),
    scaffoldBackgroundColor: colors.page_background,
    dialogTheme: DialogThemeData(backgroundColor: colors.card_background),
    popupMenuTheme: PopupMenuThemeData(color: colors.card_background),
    // 內建 Noto Sans TC（子集化常用繁中字）：全平台（含網頁）字型一致，
    // 罕用字退回系統字型
    fontFamily: 'NotoSansTC',
    fontFamilyFallback: const <String>[
      'PingFang TC', // macOS 繁中
      'Microsoft JhengHei', // Windows 繁中
      'Noto Sans TC',
    ],
  );
}
