import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design system for Al-Qassam Mobile App.
/// Adheres to Material 3, Cairo typography, and specialized Arabic financial colors.
class AppTheme {
  // Brand colors
  static const Color primaryEmerald = Color(0xFF0F766E); // Deep Emerald Teal
  static const Color primaryLight = Color(0xFF14B8A6);   // Bright Teal
  static const Color accentAmber = Color(0xFFD97706);    // Gold / Amber for Totals
  static const Color surfaceDark = Color(0xFF0F172A);    // Rich Slate/Navy Dark
  static const Color cardDark = Color(0xFF1E293B);       // Dark Card
  static const Color bgLight = Color(0xFFF8FAFC);        // Soft cool white
  static const Color cardLight = Colors.white;
  static const Color textMainLight = Color(0xFF0F172A);
  static const Color textSubLight = Color(0xFF64748B);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color successGreen = Color(0xFF16A34A);

  /// Light Material 3 Theme
  static ThemeData lightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryEmerald,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFCCFBF1),
        onPrimaryContainer: const Color(0xFF115E59),
        secondary: accentAmber,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFFEF3C7),
        onSecondaryContainer: const Color(0xFF92400E),
        surface: bgLight,
        onSurface: textMainLight,
        error: dangerRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: bgLight,
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textMainLight,
        ),
        iconTheme: const IconThemeData(color: textMainLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryEmerald,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryEmerald,
          side: const BorderSide(color: primaryEmerald, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryEmerald, width: 2),
        ),
        hintStyle: GoogleFonts.cairo(color: textSubLight, fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        elevation: 1,
        backgroundColor: Colors.white,
        indicatorColor: primaryEmerald.withValues(alpha: 0.16),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? primaryEmerald : textSubLight,
            height: 1.25,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected ? primaryEmerald : textSubLight,
          );
        }),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
    );
  }

  /// Dark Material 3 Theme
  static ThemeData darkTheme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryLight,
        onPrimary: const Color(0xFF042F2E),
        primaryContainer: const Color(0xFF134E4A),
        onPrimaryContainer: const Color(0xFFCCFBF1),
        secondary: const Color(0xFFF59E0B),
        onSecondary: const Color(0xFF451A03),
        secondaryContainer: const Color(0xFF78350F),
        onSecondaryContainer: const Color(0xFFFEF3C7),
        surface: surfaceDark,
        onSurface: Colors.white,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: surfaceDark,
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cardDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cairo(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: const Color(0xFF042F2E),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          side: const BorderSide(color: primaryLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF475569)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        hintStyle: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        elevation: 0,
        backgroundColor: cardDark,
        indicatorColor: primaryLight.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? primaryLight : const Color(0xFF94A3B8),
            height: 1.25,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected ? primaryLight : const Color(0xFF94A3B8),
          );
        }),
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
    );
  }

  /// Card background color aware of dark mode
  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? cardDark
        : cardLight;
  }

  /// Subtle container/pill background color aware of dark mode
  static Color getSubtleBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
  }

  /// Border color aware of dark mode
  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
  }

  /// Primary text color aware of dark mode
  static Color getTextMain(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : textMainLight;
  }

  /// Secondary text color aware of dark mode
  static Color getTextSub(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : textSubLight;
  }
}
