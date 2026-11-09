import 'package:flutter/material.dart';

/// 메디텀 팔레트 — 리링 간호사(민트 모자·분홍 머리)에 맞춘 민트 + 핑크.
/// ⚠️ 단추 모양은 여기서만 정한다. 화면마다 따로 꾸미지 않는다.
class AppTheme {
  AppTheme._();

  static const primary = Color(0xFF38AAA0); // 민트 (글씨·단추)
  static const mint = Color(0xFF5ECDBE); // 밝은 민트 (아이콘 배경)
  static const mintSoft = Color(0xFFDFF5F0); // 카드 배경
  static const pink = Color(0xFFFF8FAB); // 포인트
  static const pinkSoft = Color(0xFFFFE4EC);
  static const ink = Color(0xFF1F3B3A); // 본문
  static const inkSoft = Color(0xFF5B7472);
  static const star = Color(0xFFFFC93C);
  static const correct = Color(0xFF3CB371);
  static const wrong = Color(0xFFE85D6F);
  static const background = Color(0xFFF4FBF9);

  static const buttonHeight = 54.0;
  static const radius = 20.0;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light).copyWith(
      primary: primary,
      secondary: pink,
      onSurface: ink,
      surface: Colors.white,
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    const label = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true, scaffoldBackgroundColor: background);
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: primary.withValues(alpha: 0.14)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, buttonHeight),
          shape: shape,
          textStyle: label,
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: primary.withValues(alpha: 0.35),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, buttonHeight),
          shape: shape,
          textStyle: label,
          foregroundColor: primary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: primary, width: 1.6),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          foregroundColor: primary,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
        selectedColor: mintSoft,
        backgroundColor: Colors.white,
        side: BorderSide(color: primary.withValues(alpha: 0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primary.withValues(alpha: 0.3))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primary.withValues(alpha: 0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: primary, width: 2)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : null),
      ),
      sliderTheme: const SliderThemeData(activeTrackColor: primary, thumbColor: primary),
      dividerTheme: DividerThemeData(color: primary.withValues(alpha: 0.12)),
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    );
  }
}
