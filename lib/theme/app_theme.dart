import 'package:flutter/material.dart';
import 'design_tokens.dart';

const kPrimaryPurple = Color(0xFF7E57C2);

ThemeMode resolveThemeMode(String value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

ThemeData buildLightTheme(int seedColor) {
  return _buildTheme(seedColor, Brightness.light);
}

ThemeData buildDarkTheme(int seedColor) {
  return _buildTheme(seedColor, Brightness.dark);
}

ThemeData _buildTheme(int seedColor, Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  // 디자인 팔레트를 기준으로 삼고, 사용자가 고른 색은 accent(=primary)로만 쓴다.
  final tokens = isDark
      ? DesignTokens.dark(Color(seedColor))
      : DesignTokens.light(Color(seedColor));

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: Color(seedColor),
        brightness: brightness,
      ).copyWith(
        // 시드색이 섞인 라벤더 톤 표면을 걷어내고 캘린더 화면의 종이·먹 팔레트로
        // 통일한다. 사용자 색은 primary(강조)에만 남긴다.
        // 캘린더 FAB 처럼 사용자가 고른 색 그대로. (fromSeed 의 primary 는
        // 톤이 한 단계 탁해져 화면마다 보라가 두 가지로 보였다)
        primary: tokens.accent,
        onPrimary:
            ThemeData.estimateBrightnessForColor(tokens.accent) ==
                Brightness.dark
            ? Colors.white
            : DesignTokens.light(tokens.accent).ink,
        surface: tokens.bg,
        onSurface: tokens.ink,
        surfaceContainerLowest: tokens.surface,
        surfaceContainerLow: tokens.surface,
        surfaceContainer: tokens.surface,
        surfaceContainerHigh: tokens.surface,
        surfaceContainerHighest: Color.alphaBlend(tokens.fill, tokens.bg),
        onSurfaceVariant: tokens.ink45,
        outline: tokens.ink18,
        outlineVariant: tokens.line,
        primaryContainer: Color.alphaBlend(
          tokens.accent.withValues(alpha: isDark ? 0.22 : 0.12),
          tokens.surface,
        ),
        onPrimaryContainer: tokens.ink,
        // 선택 상태(세그먼트·칩)는 캘린더의 선택일처럼 먹색 채움
        secondaryContainer: tokens.pill,
        onSecondaryContainer: tokens.pillInk,
        tertiaryContainer: Color.alphaBlend(tokens.fill, tokens.surface),
        onTertiaryContainer: tokens.ink70,
        inverseSurface: tokens.ink,
        onInverseSurface: tokens.pillInk,
      );
  final base = ThemeData(
    colorScheme: colorScheme,
    brightness: brightness,
    useMaterial3: true,
  );

  final textTheme = base.textTheme.copyWith(
    headlineLarge: base.textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -1.1,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.55,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.35,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    ),
  );

  return base.copyWith(
    extensions: [tokens],
    scaffoldBackgroundColor: colorScheme.surface,
    canvasColor: colorScheme.surface,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: colorScheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 60,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontSize: 18,
        letterSpacing: -0.4,
      ),
    ),
    // 그림자 없이 가는 선만. (옛 코드의 withValues(alpha:)는 line 의 투명도를
    // 곱하지 않고 덮어써서 테두리가 55% 먹색으로 진하게 나왔다)
    cardTheme: CardThemeData(
      color: tokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.line),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.surface,
      modalBackgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: tokens.ink18,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      // 테두리 없는 옅은 채움, 포커스일 때만 먹색 선
      fillColor: tokens.fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tokens.ink, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: const StadiumBorder(),
        side: BorderSide(color: tokens.ink18),
        foregroundColor: tokens.ink,
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(shape: const CircleBorder()),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: tokens.surface,
      selectedColor: tokens.pill,
      checkmarkColor: tokens.pillInk,
      side: BorderSide(color: tokens.line),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      // 선택 칩은 먹색 채움이라 글자도 상태에 따라 뒤집는다
      labelStyle: textTheme.labelLarge?.copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.pillInk
              : tokens.ink,
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      textColor: colorScheme.onSurface,
      minTileHeight: 58,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(
      color: tokens.hairline,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colorScheme.primary,
      linearTrackColor: tokens.fill,
      circularTrackColor: tokens.fill,
      borderRadius: BorderRadius.circular(99),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: tokens.line)),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: tokens.ink,
      unselectedLabelColor: tokens.ink45,
      indicatorColor: tokens.ink,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: tokens.hairline,
      labelStyle: textTheme.labelLarge,
    ),
  );
}
