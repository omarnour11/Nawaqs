import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nawakes_mobile/core/theme/app_theme.dart';
import 'package:nawakes_mobile/core/theme/theme_mode_provider.dart';
import 'package:nawakes_mobile/core/utils/arabic_digits.dart';
import 'package:nawakes_mobile/features/splash/presentation/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Brand Kit Typography & Arabic Numerals (Page 6)', () {
    test('ArabicDigits formats currency prices and integers authentically', () {
      expect(ArabicDigits.formatPrice(45.50), equals('٤٥٫٥٠ ج.م'));
      expect(ArabicDigits.formatPrice(120), equals('١٢٠ ج.م'));
      expect(ArabicDigits.formatPrice(0), equals('٠ ج.م'));

      expect(45.50.toArabicPrice(), equals('٤٥٫٥٠ ج.م'));
      expect(12.toArabicDigits(), equals('١٢'));
      expect('Order 123'.toArabicDigits(), equals('Order ١٢٣'));
    });

    test('AppTypography specifies Brand Kit Lalezar and Cairo fonts', () {
      final header = AppTypography.mainHeader();
      expect(header.fontFamily, equals('Lalezar'));

      final sub = AppTypography.subHeader();
      expect(sub.fontFamily, equals('Lalezar'));

      final body = AppTypography.body();
      expect(body.fontFamily, equals('Cairo'));
      expect(body.fontWeight, equals(FontWeight.w400));

      final important = AppTypography.important();
      expect(important.fontFamily, equals('Cairo'));
      expect(important.fontWeight, equals(FontWeight.w700));

      final price = AppTypography.price();
      expect(price.fontFamily, equals('Cairo'));
      expect(price.fontWeight, equals(FontWeight.w900));
    });
  });

  group('Dark Mode & Theme Switching (الوضع الليلي)', () {
    test('AppTheme.darkTheme has high contrast Deep Midnight Teal and Ink surfaces', () {
      final dark = AppTheme.darkTheme;
      expect(dark.brightness, equals(Brightness.dark));
      expect(dark.scaffoldBackgroundColor, equals(const Color(0xFF0A1A17)));
      expect(dark.colorScheme.surface, equals(const Color(0xFF12222B)));
      expect(dark.colorScheme.onSurface, equals(const Color(0xFFFBF7F0)));
    });

    test('ThemeModeNotifier toggles between light and dark modes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), equals(ThemeMode.light));

      container.read(themeModeProvider.notifier).toggleTheme();
      expect(container.read(themeModeProvider), equals(ThemeMode.dark));

      container.read(themeModeProvider.notifier).toggleTheme();
      expect(container.read(themeModeProvider), equals(ThemeMode.light));
    });
  });

  group('Delete Account Phrase Fuzzy Matcher', () {
    String norm(String s) => s
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll(RegExp(r'[أإآا]'), 'ا')
        .replaceAll(RegExp(r'[يى]'), 'ي')
        .replaceAll(RegExp(r'[ةه]'), 'ه')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();

    bool matches(String input) => norm(input) == norm('لو احتجت نواقص تاني هجيلكم');

    test('Tolerates hamza, alef maksura, and whitespace differences', () {
      expect(matches('لو احتجت نواقص تاني هجيلكم'), isTrue);
      expect(matches('لو إحتجت نواقص تانى هجيلكم'), isTrue);
      expect(matches('لو   احتجت  نواقص   تاني  هجيلكم  '), isTrue);
      expect(matches('لو احتجت نواقص تاني هجيلكو'), isFalse);
      expect(matches('عايز احذف حسابي'), isFalse);
    });
  });

  group('Splash Screen UI (Brand Kit Page 14)', () {
    testWidgets('Renders Nawaqss Brand Logo and Lalezar Arabic titles', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      expect(find.text('نواقص'), findsOneWidget);
      expect(find.text('صوّر الروشتة وخلاص'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}