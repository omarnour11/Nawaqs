import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ─── Nawaqss Brand Design Tokens (Nawaqss Brand Kit v3) ───────────────────
///
/// Authentic Egyptian medicine SaaS palette:
/// • Teal (#0E7C6B): Brand chrome, primary buttons, large banners.
/// • Coral (#FF5A4E): 10% Rule — scan hero action, "ناقص" alert, primary actions.
/// • Cream (#FBF7F0): Soft warm page background.
/// • Mint (#D8F3EA): Clean card surfaces, "متاح" available badges.
/// • Ink (#12222B): High-contrast readable typography (15.3:1 ratio).
/// • Yellow (#FFD23F): Highlighter sticker, "قريب" nearby badges.
class NawaqsColors {
  NawaqsColors._();

  static const teal = Color(0xFF0E7C6B);
  static const tealDark = Color(0xFF0A5A4E);
  static const coral = Color(0xFFFF5A4E);
  static const coralSoft = Color(0xFFFFE1DD);
  static const cream = Color(0xFFFBF7F0);
  static const mint = Color(0xFFD8F3EA);
  static const mintDeep = Color(0xFFA9DECB);
  static const ink = Color(0xFF12222B);
  static const stickerYellow = Color(0xFFFFD23F);
}

class AppColors {
  AppColors._();

  /// Global mode flag synchronized with themeModeProvider
  static bool isDarkMode = false;

  // Brand — deep teal (#0E7C6B, #0A5A4E)
  static const brand900 = NawaqsColors.tealDark; // #0A5A4E
  static const brand700 = NawaqsColors.teal;     // #0E7C6B

  // Accent — interactive brand teal & coral
  static const accentBlue = NawaqsColors.teal;
  static const accentBlueBg = NawaqsColors.mint;
  static const coralAccent = NawaqsColors.coral;
  static const coralAccentBg = NawaqsColors.coralSoft;

  // Semantic triplets
  static const successBg = NawaqsColors.mint;
  static const successText = NawaqsColors.tealDark;
  static const successIcon = NawaqsColors.teal;

  static const warningBg = Color(0xFFFFF9E6);
  static const warningText = Color(0xFF8C6500);
  static const warningIcon = NawaqsColors.stickerYellow;

  static const dangerBg = NawaqsColors.coralSoft;
  static const dangerText = NawaqsColors.coral;
  static const dangerIcon = NawaqsColors.coral;

  // Surfaces (Brand Kit Page 5)
  static const page = NawaqsColors.cream;
  static const card = Colors.white;
  static const fieldBg = Colors.white;
  static const hairline = Color(0xFFE2EFE9);
  static const neutralChipBg = NawaqsColors.mint;

  // Text (High-contrast Ink)
  static const textPrimary = NawaqsColors.ink;
  static const textSecondary = Color(0xFF4A5D68);
  static const textMuted = Color(0xFF7F95A0);
  static const textDark = textPrimary;

  // Legacy aliases for older screens
  static const primary = accentBlue;
  static const primaryLight = NawaqsColors.teal;
  static const primaryDark = brand900;
  static const primarySurface = accentBlueBg;
  static const accent = coralAccent;
  static const accentLight = coralAccentBg;
  static const accentDark = dangerText;
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
  static const surfaceVariant = NawaqsColors.mint;
  static const border = hairline;
  static const shadow = Color(0x14101828);
  static const textHint = textMuted;

  // Dynamic Theme Helpers
  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF142730)
          : Colors.white;

  static Color pageOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0A1A17)
          : NawaqsColors.cream;

  static Color textOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFFBF7F0)
          : NawaqsColors.ink;

  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFA9DECB)
          : const Color(0xFF4A5D68);

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E3A33)
          : hairline;
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
  static const sm = 8.0;
  static const md = 14.0; // 14px buttons (Brand Kit Page 11 & 17)
  static const lg = 16.0; // 16px cards (Brand Kit Page 11 & 17)
  static const xl = 22.0; // 22px sheets (Brand Kit Page 17)
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    const family = 'Cairo';
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: NawaqsColors.teal,
      onPrimary: Colors.white,
      primaryContainer: NawaqsColors.mint,
      onPrimaryContainer: NawaqsColors.tealDark,
      secondary: NawaqsColors.coral,
      onSecondary: Colors.white,
      secondaryContainer: NawaqsColors.coralSoft,
      onSecondaryContainer: NawaqsColors.coral,
      error: NawaqsColors.coral,
      onError: Colors.white,
      errorContainer: NawaqsColors.coralSoft,
      onErrorContainer: NawaqsColors.coral,
      surface: NawaqsColors.cream,
      onSurface: NawaqsColors.ink,
      surfaceContainerHighest: NawaqsColors.mint,
      onSurfaceVariant: NawaqsColors.ink.withValues(alpha: 0.7),
      outline: const Color(0xFFD3E7DE),
      outlineVariant: const Color(0xFFE4F0EA),
    );

    ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: NawaqsColors.cream,
      fontFamily: family,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: NawaqsColors.cream,
        foregroundColor: NawaqsColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: const IconThemeData(color: NawaqsColors.ink),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
          side: const BorderSide(color: Color(0xFFE2EFE9), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2EFE9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2EFE9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NawaqsColors.teal, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NawaqsColors.coral),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NawaqsColors.coral, width: 1.6),
        ),
        hintStyle: const TextStyle(color: Color(0xFF7F95A0), fontSize: 13.5),
        labelStyle: const TextStyle(color: Color(0xFF4A5D68), fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NawaqsColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E7EA),
          disabledForegroundColor: const Color(0xFF7F95A0),
          minimumSize: const Size(64, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(
              fontFamily: family, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NawaqsColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E7EA),
          disabledForegroundColor: const Color(0xFF7F95A0),
          minimumSize: const Size(64, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(
              fontFamily: family, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NawaqsColors.ink,
          minimumSize: const Size(64, 46),
          side: const BorderSide(color: Color(0xFFE2EFE9), width: 1),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(
              fontFamily: family, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NawaqsColors.teal,
          textStyle: const TextStyle(
              fontFamily: family, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: NawaqsColors.mint,
        height: 64,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: family,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: NawaqsColors.teal,
            );
          }
          return const TextStyle(
            fontFamily: family,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF7F95A0),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(size: 22, color: NawaqsColors.teal);
          }
          return const IconThemeData(size: 22, color: Color(0xFF7F95A0));
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? NawaqsColors.teal
                : const Color(0xFFE5E7EA)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? NawaqsColors.teal : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: NawaqsColors.mint.withValues(alpha: 0.5),
        selectedColor: NawaqsColors.mint,
        checkmarkColor: NawaqsColors.teal,
        labelStyle: const TextStyle(
            fontFamily: family, fontSize: 11.5, fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
        side: const BorderSide(color: Color(0xFFD4E6DF), width: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
          color: Color(0xFFE2EFE9), thickness: 1, space: 1),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: NawaqsColors.coral,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: NawaqsColors.tealDark,
        contentTextStyle: const TextStyle(
            fontFamily: family,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        titleTextStyle: const TextStyle(
            fontFamily: family,
            color: NawaqsColors.ink,
            fontSize: 16.5,
            fontWeight: FontWeight.w800),
        contentTextStyle: const TextStyle(
            fontFamily: family,
            color: Color(0xFF4A5D68),
            fontSize: 13.5,
            height: 1.55),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: true,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: NawaqsColors.teal),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontFamily: family,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: NawaqsColors.ink,
            height: 1.25),
        headlineMedium: TextStyle(
            fontFamily: family,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: NawaqsColors.ink,
            height: 1.3),
        headlineSmall: TextStyle(
            fontFamily: family,
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
            color: NawaqsColors.ink,
            height: 1.3),
        titleLarge: TextStyle(
            fontFamily: family,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: NawaqsColors.ink,
            height: 1.35),
        titleMedium: TextStyle(
            fontFamily: family,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: NawaqsColors.ink,
            height: 1.35),
        titleSmall: TextStyle(
            fontFamily: family,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: NawaqsColors.ink,
            height: 1.35),
        bodyLarge: TextStyle(
            fontFamily: family,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: NawaqsColors.ink,
            height: 1.55),
        bodyMedium: TextStyle(
            fontFamily: family,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: NawaqsColors.ink,
            height: 1.55),
        bodySmall: TextStyle(
            fontFamily: family,
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: Color(0xFF4A5D68),
            height: 1.5),
        labelLarge: TextStyle(
            fontFamily: family,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: NawaqsColors.ink),
        labelMedium: TextStyle(
            fontFamily: family,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4A5D68)),
        labelSmall: TextStyle(
            fontFamily: family,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7F95A0),
            letterSpacing: 0.0,
            height: 1.3),
      ),
    );
  }

  /// Official Nawaqss Brand Kit Dark Theme:
  /// Designed around Deep Midnight Teal (#0A1A17) scaffold, High-contrast Deep Ink (#12222B)
  /// card surfaces, Mint Deep (#A9DECB) accents and Warm Cream (#FBF7F0) high-contrast text.
  static ThemeData get darkTheme {
    const family = 'Cairo';
    const darkScaffold = Color(0xFF0A1A17); // Deep Midnight Teal
    const darkSurface = Color(0xFF12222B);  // High contrast Deep Ink
    const darkCard = Color(0xFF142730);     // Elevated card surface
    const darkBorder = Color(0xFF1E3A33);   // Subtle teal outline
    const darkTextPrimary = Color(0xFFFBF7F0); // Warm Mint Cream
    const darkTextSecondary = Color(0xFFA9DECB); // Mint Deep
    const darkTextMuted = Color(0xFF75918A);

    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: NawaqsColors.teal,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF133830),
      onPrimaryContainer: const Color(0xFFD8F3EA),
      secondary: NawaqsColors.coral,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF3E1E1B),
      onSecondaryContainer: NawaqsColors.coralSoft,
      error: NawaqsColors.coral,
      onError: Colors.white,
      errorContainer: const Color(0xFF3E1E1B),
      onErrorContainer: NawaqsColors.coral,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: const Color(0xFF162C27),
      onSurfaceVariant: darkTextSecondary,
      outline: darkBorder,
      outlineVariant: const Color(0xFF18302A),
    );

    ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkScaffold,
      cardColor: darkCard,
      canvasColor: darkScaffold,
      dialogBackgroundColor: darkCard,
      fontFamily: family,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: darkScaffold,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0F1E25),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NawaqsColors.mintDeep, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NawaqsColors.coral),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NawaqsColors.coral, width: 1.6),
        ),
        hintStyle: const TextStyle(color: darkTextMuted, fontSize: 13.5),
        labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: NawaqsColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF1F2D33),
          disabledForegroundColor: darkTextMuted,
          minimumSize: const Size(64, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(
              fontFamily: family, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: NawaqsColors.teal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF1F2D33),
          disabledForegroundColor: darkTextMuted,
          minimumSize: const Size(64, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(
              fontFamily: family, fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          minimumSize: const Size(64, 46),
          side: const BorderSide(color: darkBorder, width: 1),
          backgroundColor: darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: const TextStyle(
              fontFamily: family, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: NawaqsColors.mintDeep,
          textStyle: const TextStyle(
              fontFamily: family, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF16382F),
        height: 64,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: family,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: NawaqsColors.mintDeep,
            );
          }
          return const TextStyle(
            fontFamily: family,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: darkTextMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(size: 22, color: NawaqsColors.mintDeep);
          }
          return const IconThemeData(size: 22, color: darkTextMuted);
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        titleTextStyle: const TextStyle(
            fontFamily: family,
            color: darkTextPrimary,
            fontSize: 16.5,
            fontWeight: FontWeight.w800),
        contentTextStyle: const TextStyle(
            fontFamily: family,
            color: darkTextSecondary,
            fontSize: 13.5,
            height: 1.55),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkCard,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        showDragHandle: true,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: NawaqsColors.mintDeep),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontFamily: family,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: darkTextPrimary,
            height: 1.25),
        headlineMedium: TextStyle(
            fontFamily: family,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: darkTextPrimary,
            height: 1.3),
        headlineSmall: TextStyle(
            fontFamily: family,
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
            color: darkTextPrimary,
            height: 1.3),
        titleLarge: TextStyle(
            fontFamily: family,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: darkTextPrimary,
            height: 1.35),
        titleMedium: TextStyle(
            fontFamily: family,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: darkTextPrimary,
            height: 1.35),
        titleSmall: TextStyle(
            fontFamily: family,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: darkTextPrimary,
            height: 1.35),
        bodyLarge: TextStyle(
            fontFamily: family,
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: darkTextPrimary,
            height: 1.55),
        bodyMedium: TextStyle(
            fontFamily: family,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: darkTextPrimary,
            height: 1.55),
        bodySmall: TextStyle(
            fontFamily: family,
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            color: darkTextSecondary,
            height: 1.5),
        labelLarge: TextStyle(
            fontFamily: family,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: darkTextPrimary),
        labelMedium: TextStyle(
            fontFamily: family,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: darkTextSecondary),
        labelSmall: TextStyle(
            fontFamily: family,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: darkTextMuted,
            letterSpacing: 0.0,
            height: 1.3),
      ),
    );
  }
}

/// Brand Kit Page 6: Typography Hierarchy
/// العناوين والستيكرز: Lalezar 400
/// النصوص والتطبيق: Cairo 400 · 700 · 900
class AppTypography {
  AppTypography._();

  static const String titleFont = 'Lalezar';
  static const String bodyFont = 'Cairo';

  /// عنوان رئيسي: Lalezar 400 (48–80)
  static TextStyle mainHeader({
    double fontSize = 48,
    Color? color,
    double height = 1.15,
  }) =>
      TextStyle(
        fontFamily: titleFont,
        fontWeight: FontWeight.w400,
        fontSize: fontSize,
        color: color ?? AppColors.textPrimary,
        height: height,
      );

  /// عنوان فرعي / يعرف: Lalezar 400 (28–36)
  static TextStyle subHeader({
    double fontSize = 28,
    Color? color,
    double height = 1.25,
  }) =>
      TextStyle(
        fontFamily: titleFont,
        fontWeight: FontWeight.w400,
        fontSize: fontSize,
        color: color ?? AppColors.textPrimary,
        height: height,
      );

  /// نص أساسي: Cairo 400 (14–18)
  static TextStyle body({
    double fontSize = 15,
    Color? color,
    double height = 1.55,
  }) =>
      TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w400,
        fontSize: fontSize,
        color: color ?? AppColors.textPrimary,
        height: height,
      );

  /// نص مهم / أزرار: Cairo 700 (14–18)
  static TextStyle important({
    double fontSize = 15,
    Color? color,
    double height = 1.4,
  }) =>
      TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
        color: color ?? AppColors.textPrimary,
        height: height,
      );

  /// أرقام وأسعار: Cairo 900 (20–32)
  static TextStyle price({
    double fontSize = 22,
    Color? color,
    double height = 1.2,
  }) =>
      TextStyle(
        fontFamily: bodyFont,
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
        color: color ?? NawaqsColors.teal,
        height: height,
      );
}
