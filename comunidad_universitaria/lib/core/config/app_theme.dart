import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../constants/zanate_colors.dart';

class AppTheme {
  // USAC Palette & Modern Tech Aesthetic
  static const Color usacBlue = Color(0xFF004B87);
  static const Color usacBlueLight = Color(0xFF0066CC);
  static const Color usacGold = Color(0xFFEAB308);
  static const Color usacAccent = Color(0xFF2563EB);

  // Light colors
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark colors (Negro Plumaje + Amarillo Zanate)
  static const Color darkBg = ZanateColors.darkBg;
  static const Color darkCard = ZanateColors.darkSurface;
  static const Color darkCardSubtle = ZanateColors.darkSurfaceSubtle;
  static const Color darkBorder = ZanateColors.darkBorder;
  static const Color darkTextPrimary = ZanateColors.darkTextPrimary;
  static const Color darkTextSecondary = ZanateColors.darkTextSecondary;

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ZanateColors.zanateBlack,
        primary: ZanateColors.zanateBlack,
        onPrimary: Colors.white,
        secondary: ZanateColors.zanateEyeYellow,
        onSecondary: ZanateColors.zanateBlack,
        surface: ZanateColors.cardBg,
        outline: ZanateColors.subtleBorder,
        onSurface: ZanateColors.zanateBlack,
        onSurfaceVariant: ZanateColors.subtleText,
      ),
      scaffoldBackgroundColor: Colors.white,
      textTheme: baseTextTheme.copyWith(
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: ZanateColors.zanateBlack,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: ZanateColors.zanateBlack,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: ZanateColors.zanateBlack,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: ZanateColors.subtleText,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ZanateColors.zanateBlack,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const Icon(PhosphorIconsBold.caretLeft, size: 22),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ZanateColors.zanateBlack,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ZanateColors.subtleBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: ZanateColors.subtleBorder),
        ),
      ),
      cardTheme: CardThemeData(
        color: ZanateColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: ZanateColors.subtleBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ZanateColors.pillBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ZanateColors.surfaceBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ZanateColors.subtleBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ZanateColors.subtleBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: ZanateColors.zanateBlack,
            width: 1.6,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZanateColors.zanateBlack,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ZanateColors.zanateBlack,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZanateColors.zanateBlack,
          side: const BorderSide(color: ZanateColors.subtleBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZanateColors.zanateBlack,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ZanateColors.zanateEyeYellow,
        brightness: Brightness.dark,
        primary: ZanateColors.zanateEyeYellow,
        onPrimary: ZanateColors.zanateBlack,
        secondary: ZanateColors.zanateEyeYellow,
        onSecondary: ZanateColors.zanateBlack,
        surface: darkCard,
        surfaceContainer: darkCard,
        surfaceContainerLow: darkBg,
        surfaceContainerHigh: darkCardSubtle,
        surfaceContainerHighest: darkCardSubtle,
        outline: darkBorder,
        outlineVariant: darkBorder,
        onSurface: darkTextPrimary,
        onSurfaceVariant: darkTextSecondary,
      ),
      scaffoldBackgroundColor: darkBg,
      dividerColor: darkBorder,
      canvasColor: darkBg,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ZanateColors.zanateEyeYellow,
      ),
      textTheme: baseTextTheme.copyWith(
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: darkTextPrimary,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: darkTextPrimary),
        bodySmall: baseTextTheme.bodySmall?.copyWith(color: darkTextSecondary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCard,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
      ),
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const Icon(PhosphorIconsBold.caretLeft, size: 22),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkBg,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkBg,
        modalBackgroundColor: darkBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: darkBorder),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkCard,
        indicatorColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: ZanateColors.zanateEyeYellow,
              size: 23,
            );
          }
          return const IconThemeData(
            color: ZanateColors.darkTextMuted,
            size: 23,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkCardSubtle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: darkBorder),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCardSubtle,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: const TextStyle(color: ZanateColors.darkTextMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: ZanateColors.zanateEyeYellow,
            width: 1.6,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ZanateColors.zanateEyeYellow,
          foregroundColor: ZanateColors.zanateBlack,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ZanateColors.zanateEyeYellow,
          foregroundColor: ZanateColors.zanateBlack,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkTextPrimary,
          side: const BorderSide(color: darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZanateColors.zanateEyeYellow,
        ),
      ),
    );
  }
}
