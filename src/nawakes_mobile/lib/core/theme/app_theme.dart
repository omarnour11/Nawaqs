import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ─── Nawaqs Design Tokens (from the official design spec) ───────────────────
///
/// Calm, clinical, trustworthy. Color always carries meaning
/// (available/limited/unavailable, verified/pending) — never decoration.
/// One saturated accent (blue) for interactive elements; teal is brand chrome.
class AppColors {
  AppColors._();

  // Brand — deep teal (chrome only, never actions)
  static const brand900 = Color(0xFF123B39); // app mark, pass hero, confirmed banner
  static const brand700 = Color(0xFF0F6E56); // selected states, links in dark banners

  // Accent — interactive blue (CTAs, links, active nav)
  static const accentBlue = Color(0xFF2E6FF2);
  static const accentBlueBg = Color(0xFFE9F0FE);

  // Semantic — background / text / icon triplets
  static const successBg = Color(0xFFE4F5EA);
  static const successText = Color(0xFF1B7A4B);
  static const successIcon = Color(0xFF2E9A63);

  static const warningBg = Color(0xFFFCF0D9);
  static const warningText = Color(0xFF92640B);
  static const warningIcon = Color(0xFFD99A2B);

  static const dangerBg = Color(0xFFFBEAEA);
  static const dangerText = Color(0xFFB23A3A);
  static const dangerIcon = Color(0xFFD2544F);

  // Surfaces
  static const page = Color(0xFFF4F5F7);
  static const card = Color(0xFFFFFFFF);
  static const fieldBg = Color(0xFFFAFAFB);
  static const hairline = Color(0xFFE7E8EB);
  static const neutralChipBg = Color(0xFFF1F2F4);

  // Text
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);

  // Legacy aliases for older screens
  static const primary = accentBlue;
  static const primaryLight = Color(0xFF5B8FF5);
  static const primaryDark = brand900;
  static const primarySurface = accentBlueBg;
  static const accent = warningIcon;
  static const accentLight = warningBg;
  static const accentDark = warningText;
  static const success = successText;
  static const successSurface = successBg;
  static const danger = dangerText;
  static const dangerSurface = dangerBg;
  static const warning = warningText;
  static const warningSurface = warningBg;
  static const info = accentBlue;
  static const infoSurface = accentBlueBg;
  static const available = successIcon;
  static const unavailable = dangerIcon;
  static const background = page;
  static const surface = card;
  static const surfaceVariant = Color(0xFFF1F2F4);
  static const border = hairline;
  static const shadow = Color(0x14101828);
  static const textHint = textMuted;
}

class AppShadows {
  AppShadows._();

  /// Only used on floating map controls — spec forbids drop shadows on cards.
  static const mapFloat = [
    BoxShadow(color: Color(0x1A101828), blurRadius: 10, offset: Offset(0, 3)),
  ];

  static const soft = mapFloat;
  static const floating = mapFloat;
}

class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 18.0;
  static const xl = 24.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    const family = 'Cairo';
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.accentBlue,
      onPrimary: Colors.white,
      primaryContainer: AppColors.accentBlueBg,
      onPrimaryContainer: AppColors.accentBlue,
      secondary: AppColors.brand700,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFD9EDE7),
      onSecondaryContainer: AppColors.brand700,
      error: AppColors.dangerText,
      onError: Colors.white,
      errorContainer: AppColors.dangerBg,
      onErrorContainer: AppColors.dangerText,
      surface: AppColors.card,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: Color(0xFFF1F2F4),
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.hairline,
      outlineVariant: AppColors.hairline,
    );

    ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.page,
      fontFamily: family,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.page,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: const BorderSide(color: AppColors.hairline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fieldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accentBlue, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.dangerIcon),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.dangerIcon, width: 1.6),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13.5),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E7EA),
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(
              fontFamily: family, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E7EA),
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(
              fontFamily: family, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(46),
          side: const BorderSide(color: AppColors.hairline, width: 1),
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(
              fontFamily: family, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentBlue,
          textStyle: const TextStyle(
              fontFamily: family, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 64,
        elevation: 0,
        labelTextStyle: const WidgetStatePropertyAll(TextStyle(
            fontFamily: family,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted)),
        iconTheme: const WidgetStatePropertyAll(
            IconThemeData(size: 22, color: AppColors.textMuted)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.successIcon
                : const Color(0xFFE5E7EA)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.accentBlue : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F2F4),
        selectedColor: AppColors.accentBlueBg,
        checkmarkColor: AppColors.accentBlue,
        labelStyle: const TextStyle(
            fontFamily: family, fontSize: 11.5, fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
          color: AppColors.hairline, thickness: 1, space: 1),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentBlue,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.brand900,
        contentTextStyle: const TextStyle(
            fontFamily: family,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        titleTextStyle: const TextStyle(
            fontFamily: family,
            color: AppColors.textPrimary,
            fontSize: 16.5,
            fontWeight: FontWeight.w800),
        contentTextStyle: const TextStyle(
            fontFamily: family,
            color: AppColors.textSecondary,
            fontSize: 13.5,
            height: 1.55),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: true,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.accentBlue),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontFamily: family,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.25),
        headlineMedium: TextStyle(
            fontFamily: family,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.3),
        headlineSmall: TextStyle(
            fontFamily: family,
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.3),
        titleLarge: TextStyle(
            fontFamily: family,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.35),
        titleMedium: TextStyle(
            fontFamily: family,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.35),
        titleSmall: TextStyle(
            fontFamily: family,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            height: 1.35),
        bodyLarge: TextStyle(
            fontFamily: family,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
            height: 1.55),
        bodyMedium: TextStyle(
            fontFamily: family,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
            height: 1.55),
        bodySmall: TextStyle(
            fontFamily: family,
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
            height: 1.5),
        labelLarge: TextStyle(
            fontFamily: family,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary),
        labelMedium: TextStyle(
            fontFamily: family,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary),
        labelSmall: TextStyle(
            fontFamily: family,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.4,
            height: 1.3),
      ),
    );
  }
}
