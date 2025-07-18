import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryColor = Color(0xFF4B39EF);
  static const Color secondaryColor = Color(0xFF39D2C0);
  static const Color tertiaryColor = Color(0xFFEE8B60);
  static const Color alternateColor = Color(0xFFE0E3E7);
  
  // Light Theme Colors
  static const Color primaryTextLight = Color(0xFF14181B);
  static const Color secondaryTextLight = Color(0xFF57636C);
  static const Color primaryBackgroundLight = Color(0xFFF1F4F8);
  static const Color secondaryBackgroundLight = Color(0xFFFFFFFF);
  
  // Dark Theme Colors
  static const Color primaryTextDark = Color(0xFFFFFFFF);
  static const Color secondaryTextDark = Color(0xFF95A1AC);
  static const Color primaryBackgroundDark = Color(0xFF1D2428);
  static const Color secondaryBackgroundDark = Color(0xFF14181B);
  static const Color alternateDark = Color(0xFF262D34);
  
  // Semantic Colors
  static const Color successColor = Color(0xFF249689);
  static const Color errorColor = Color(0xFFFF5963);
  static const Color warningColor = Color(0xFFF9CF58);
  static const Color infoColor = Color(0xFFFFFFFF);
  
  // Accent Colors
  static const Color accent1 = Color(0x4C4B39EF);
  static const Color accent2 = Color(0x4D39D2C0);
  static const Color accent3 = Color(0x4DEE8B60);
  static const Color accent4Light = Color(0xCCFFFFFF);
  static const Color accent4Dark = Color(0xFF262D34);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
        surface: secondaryBackgroundLight,
        background: primaryBackgroundLight,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onSurface: primaryTextLight,
        onBackground: primaryTextLight,
        onError: Colors.white,
        outline: accent3,
        outlineVariant: alternateColor,
        surfaceVariant: alternateColor,
        onSurfaceVariant: secondaryTextLight,
        inverseSurface: primaryTextLight,
        onInverseSurface: primaryBackgroundLight,
        inversePrimary: primaryColor,
      ),
      textTheme: GoogleFonts.interTextTheme(
        TextTheme(
          displayLarge: TextStyle(color: primaryTextLight),
          displayMedium: TextStyle(color: primaryTextLight),
          displaySmall: TextStyle(color: primaryTextLight),
          headlineLarge: TextStyle(color: primaryTextLight),
          headlineMedium: TextStyle(color: primaryTextLight),
          headlineSmall: TextStyle(color: primaryTextLight),
          titleLarge: TextStyle(color: primaryTextLight),
          titleMedium: TextStyle(color: primaryTextLight),
          titleSmall: TextStyle(color: primaryTextLight),
          bodyLarge: TextStyle(color: primaryTextLight),
          bodyMedium: TextStyle(color: primaryTextLight),
          bodySmall: TextStyle(color: secondaryTextLight),
          labelLarge: TextStyle(color: primaryTextLight),
          labelMedium: TextStyle(color: secondaryTextLight),
          labelSmall: TextStyle(color: secondaryTextLight),
        ),
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackgroundColor: primaryBackgroundLight,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        color: secondaryBackgroundLight,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryBackgroundLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: alternateColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: alternateColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        labelStyle: TextStyle(color: secondaryTextLight),
        hintStyle: TextStyle(color: secondaryTextLight),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: secondaryBackgroundLight,
        selectedItemColor: primaryColor,
        unselectedItemColor: secondaryTextLight,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: alternateColor,
        selectedColor: primaryColor,
        labelStyle: TextStyle(color: primaryTextLight),
        secondarySelectedColor: accent1,
        brightness: Brightness.light,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryTextLight,
        contentTextStyle: TextStyle(color: primaryBackgroundLight),
        actionTextColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: alternateColor,
        thickness: 1,
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: tertiaryColor,
        surface: secondaryBackgroundDark,
        background: primaryBackgroundDark,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onSurface: primaryTextDark,
        onBackground: primaryTextDark,
        onError: Colors.white,
        outline: accent3,
        outlineVariant: alternateDark,
        surfaceVariant: alternateDark,
        onSurfaceVariant: secondaryTextDark,
        inverseSurface: primaryTextDark,
        onInverseSurface: primaryBackgroundDark,
        inversePrimary: primaryColor,
      ),
      textTheme: GoogleFonts.interTextTheme(
        TextTheme(
          displayLarge: TextStyle(color: primaryTextDark),
          displayMedium: TextStyle(color: primaryTextDark),
          displaySmall: TextStyle(color: primaryTextDark),
          headlineLarge: TextStyle(color: primaryTextDark),
          headlineMedium: TextStyle(color: primaryTextDark),
          headlineSmall: TextStyle(color: primaryTextDark),
          titleLarge: TextStyle(color: primaryTextDark),
          titleMedium: TextStyle(color: primaryTextDark),
          titleSmall: TextStyle(color: primaryTextDark),
          bodyLarge: TextStyle(color: primaryTextDark),
          bodyMedium: TextStyle(color: primaryTextDark),
          bodySmall: TextStyle(color: secondaryTextDark),
          labelLarge: TextStyle(color: primaryTextDark),
          labelMedium: TextStyle(color: secondaryTextDark),
          labelSmall: TextStyle(color: secondaryTextDark),
        ),
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackgroundColor: primaryBackgroundDark,
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardTheme(
        color: secondaryBackgroundDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: Colors.black.withOpacity(0.3),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: BorderSide(color: primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryBackgroundDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: alternateDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: alternateDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: errorColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        labelStyle: TextStyle(color: secondaryTextDark),
        hintStyle: TextStyle(color: secondaryTextDark),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: secondaryBackgroundDark,
        selectedItemColor: primaryColor,
        unselectedItemColor: secondaryTextDark,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: alternateDark,
        selectedColor: primaryColor,
        labelStyle: TextStyle(color: primaryTextDark),
        secondarySelectedColor: accent1,
        brightness: Brightness.dark,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: secondaryBackgroundDark,
        contentTextStyle: TextStyle(color: primaryTextDark),
        actionTextColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: alternateDark,
        thickness: 1,
      ),
    );
  }
  
  // Helper methods for accessing brand colors
  static Color get primary => primaryColor;
  static Color get secondary => secondaryColor;
  static Color get tertiary => tertiaryColor;
  static Color get success => successColor;
  static Color get error => errorColor;
  static Color get warning => warningColor;
  static Color get info => infoColor;
  
  // Helper method to get accent colors
  static Color accent1Color(bool isDark) => accent1;
  static Color accent2Color(bool isDark) => accent2;
  static Color accent3Color(bool isDark) => accent3;
  static Color accent4Color(bool isDark) => isDark ? accent4Dark : accent4Light;
  
  // Helper method to get text colors
  static Color primaryText(bool isDark) => isDark ? primaryTextDark : primaryTextLight;
  static Color secondaryText(bool isDark) => isDark ? secondaryTextDark : secondaryTextLight;
  
  // Helper method to get background colors
  static Color primaryBackground(bool isDark) => isDark ? primaryBackgroundDark : primaryBackgroundLight;
  static Color secondaryBackground(bool isDark) => isDark ? secondaryBackgroundDark : secondaryBackgroundLight;
  static Color alternateBackground(bool isDark) => isDark ? alternateDark : alternateColor;
}