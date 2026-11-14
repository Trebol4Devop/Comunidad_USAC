import 'package:flutter/material.dart';

import '../../core/constants/zanate_colors.dart';

/// Lenguaje visual del Marketplace ("Zanate Store").
///
/// Replica la estética cuadrada del catálogo principal: superficies planas,
/// bordes sutiles de 0.8px y radios pequeños (4px en controles, 8px en tiles).
/// Se aplica localmente al módulo para no alterar el resto de la aplicación.
class MarketplaceTheme {
  MarketplaceTheme._();

  static const BorderRadius controlRadius = BorderRadius.all(
    Radius.circular(4),
  );

  static ThemeData resolve(BuildContext context) {
    final base = Theme.of(context);
    final isDark = base.brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : ZanateColors.subtleBorder;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final foreground = isDark ? Colors.white : ZanateColors.zanateDark;

    OutlineInputBorder outline(Color color, [double width = 0.8]) {
      return OutlineInputBorder(
        borderRadius: controlRadius,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    RoundedRectangleBorder shape({Color? side, double width = 0.8}) {
      return RoundedRectangleBorder(
        borderRadius: controlRadius,
        side: BorderSide(color: side ?? borderColor, width: width),
      );
    }

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: surface,
        foregroundColor: foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        color: surface,
        shape: shape(),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: surface,
        shape: shape(),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          side: BorderSide(color: ZanateColors.subtleBorder, width: 0.8),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: outline(borderColor),
        enabledBorder: outline(borderColor),
        focusedBorder: outline(ZanateColors.zanateAccent, 1.2),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            base.elevatedButtonTheme.style?.copyWith(
              shape: WidgetStatePropertyAll(shape()),
            ) ??
            ElevatedButton.styleFrom(shape: shape()),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            base.filledButtonTheme.style?.copyWith(
              shape: WidgetStatePropertyAll(shape()),
            ) ??
            FilledButton.styleFrom(shape: shape()),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            base.outlinedButtonTheme.style?.copyWith(
              shape: WidgetStatePropertyAll(shape()),
            ) ??
            OutlinedButton.styleFrom(shape: shape()),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            base.textButtonTheme.style?.copyWith(
              shape: WidgetStatePropertyAll(shape(side: Colors.transparent)),
            ) ??
            TextButton.styleFrom(shape: shape(side: Colors.transparent)),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        shape: shape(side: Colors.transparent),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: shape(),
        side: BorderSide(color: borderColor, width: 0.8),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: shape(),
      ),
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 0.8,
        space: 0.8,
      ),
      listTileTheme: base.listTileTheme.copyWith(
        shape: shape(side: Colors.transparent),
      ),
    );
  }

  /// Envuelve una pantalla del módulo con el tema cuadrado.
  static Widget wrap(BuildContext context, Widget child) {
    return Theme(data: resolve(context), child: child);
  }
}
