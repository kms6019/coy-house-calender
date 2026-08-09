import 'package:flutter/material.dart';

/// Claude Design "Mobile calendar app design"의 팔레트.
///
/// 디자인 원본은 CSS 변수(--bg, --ink70 …)로 정의돼 있다. 여기서는 같은 이름·같은
/// 값을 ThemeExtension으로 옮겨, 캘린더 화면이 ColorScheme 대신 이 토큰을 읽는다.
@immutable
class DesignTokens extends ThemeExtension<DesignTokens> {
  final Color bg;
  final Color surface;
  final Color ink;
  final Color ink70;
  final Color ink45;
  final Color ink30;
  final Color ink18;
  final Color line;
  final Color hairline;
  final Color hover;
  final Color fill;

  /// 선택 상태의 채움색과 그 위 글자색 (--pill / --pillink)
  final Color pill;
  final Color pillInk;

  /// 강조색. 사용자가 설정에서 고른 테마 색이 여기로 들어온다.
  final Color accent;

  /// 인접 월 날짜 (원본 dimInk)
  final Color dim;

  /// 일요일·공휴일 (원본 oklch(0.55 0.16 25) / oklch(0.68 0.15 25) 근사)
  final Color sunday;

  const DesignTokens({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.ink70,
    required this.ink45,
    required this.ink30,
    required this.ink18,
    required this.line,
    required this.hairline,
    required this.hover,
    required this.fill,
    required this.pill,
    required this.pillInk,
    required this.accent,
    required this.dim,
    required this.sunday,
  });

  static const _lightInk = Color(0xFF17171A);
  static const _darkInk = Color(0xFFF2F2EF);

  factory DesignTokens.light(Color accent) => DesignTokens(
    bg: const Color(0xFFFBFBF9),
    surface: const Color(0xFFFFFFFF),
    ink: _lightInk,
    ink70: _lightInk.withValues(alpha: 0.7),
    ink45: _lightInk.withValues(alpha: 0.45),
    ink30: _lightInk.withValues(alpha: 0.3),
    ink18: _lightInk.withValues(alpha: 0.18),
    line: _lightInk.withValues(alpha: 0.08),
    hairline: _lightInk.withValues(alpha: 0.055),
    hover: _lightInk.withValues(alpha: 0.05),
    fill: _lightInk.withValues(alpha: 0.045),
    pill: _lightInk,
    pillInk: const Color(0xFFFFFFFF),
    accent: accent,
    dim: _lightInk.withValues(alpha: 0.22),
    sunday: const Color(0xFFC93B2C),
  );

  factory DesignTokens.dark(Color accent) => DesignTokens(
    bg: const Color(0xFF0F0F11),
    surface: const Color(0xFF1A1A1D),
    ink: _darkInk,
    ink70: _darkInk.withValues(alpha: 0.7),
    ink45: _darkInk.withValues(alpha: 0.45),
    ink30: _darkInk.withValues(alpha: 0.3),
    ink18: _darkInk.withValues(alpha: 0.18),
    line: _darkInk.withValues(alpha: 0.1),
    hairline: _darkInk.withValues(alpha: 0.07),
    hover: _darkInk.withValues(alpha: 0.07),
    fill: _darkInk.withValues(alpha: 0.06),
    pill: _darkInk,
    pillInk: const Color(0xFF0F0F11),
    accent: accent,
    dim: _darkInk.withValues(alpha: 0.22),
    sunday: const Color(0xFFF0796A),
  );

  /// 테마에 등록된 토큰. 없으면 밝기에 맞는 기본값.
  static DesignTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<DesignTokens>() ??
        (theme.brightness == Brightness.dark
            ? DesignTokens.dark(theme.colorScheme.primary)
            : DesignTokens.light(theme.colorScheme.primary));
  }

  @override
  DesignTokens copyWith({Color? accent}) => DesignTokens(
    bg: bg,
    surface: surface,
    ink: ink,
    ink70: ink70,
    ink45: ink45,
    ink30: ink30,
    ink18: ink18,
    line: line,
    hairline: hairline,
    hover: hover,
    fill: fill,
    pill: pill,
    pillInk: pillInk,
    accent: accent ?? this.accent,
    dim: dim,
    sunday: sunday,
  );

  @override
  DesignTokens lerp(ThemeExtension<DesignTokens>? other, double t) {
    if (other is! DesignTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return DesignTokens(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      ink: mix(ink, other.ink),
      ink70: mix(ink70, other.ink70),
      ink45: mix(ink45, other.ink45),
      ink30: mix(ink30, other.ink30),
      ink18: mix(ink18, other.ink18),
      line: mix(line, other.line),
      hairline: mix(hairline, other.hairline),
      hover: mix(hover, other.hover),
      fill: mix(fill, other.fill),
      pill: mix(pill, other.pill),
      pillInk: mix(pillInk, other.pillInk),
      accent: mix(accent, other.accent),
      dim: mix(dim, other.dim),
      sunday: mix(sunday, other.sunday),
    );
  }
}
