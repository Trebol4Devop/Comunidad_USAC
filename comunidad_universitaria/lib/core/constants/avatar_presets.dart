import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Paleta de colores e íconos compartida para avatares de usuario en toda la app.
class AvatarPresets {
  AvatarPresets._();

  static const List<Color> colors = [
    Color(0xFF004B87), // USAC Blue
    Color(0xFF0D9488), // Teal
    Color(0xFF7C3AED), // Purple
    Color(0xFFD97706), // Amber
    Color(0xFFDC2626), // Red
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF059669), // Emerald
    Color(0xFF475569), // Slate
  ];

  static const List<IconData> icons = [
    PhosphorIconsRegular.graduationCap,
    PhosphorIconsRegular.user,
    PhosphorIconsRegular.bookOpen,
    PhosphorIconsRegular.flask,
    PhosphorIconsRegular.wrench,
    PhosphorIconsRegular.palette,
    PhosphorIconsRegular.laptop,
    PhosphorIconsRegular.bank,
  ];

  static Color colorAt(int index) {
    if (colors.isEmpty) return const Color(0xFF004B87);
    return colors[index.clamp(0, colors.length - 1)];
  }

  static IconData iconAt(int index) {
    if (icons.isEmpty) return PhosphorIconsRegular.user;
    return icons[index.clamp(0, icons.length - 1)];
  }

  /// Genera un índice de color determinista a partir de un identificador de autor.
  static int deterministicColorIndex(String? seed) {
    final hash = _hashSeed(seed);
    return hash % colors.length;
  }

  /// Genera un índice de ícono determinista a partir de un identificador de autor.
  static int deterministicIconIndex(String? seed) {
    final hash = _hashSeed(seed);
    return (hash ~/ colors.length) % icons.length;
  }

  static int _hashSeed(String? seed) {
    final clean = (seed ?? '').trim();
    if (clean.isEmpty) return 0;
    int acc = 2166136261;
    for (int i = 0; i < clean.length; i++) {
      acc ^= clean.codeUnitAt(i);
      acc = (acc * 16777619) & 0x7FFFFFFF;
    }
    return acc;
  }
}
