import 'package:flutter/material.dart';

class ZanateColors {
  ZanateColors._();

  /// Primario / Textos principales / Riel activo
  static const Color zanateDark = Color(0xFF0F172A);

  /// Acento principal / Canal activo / Enlaces (Azul Marino)
  static const Color zanateAccent = Color(0xFF004B87);

  /// Fondo general del Scaffold / Feed / Píldoras inactivas
  static const Color surfaceBg = Color(0xFFF8FAFC);

  /// Fondo del riel lateral izquierdo del Drawer (servidores/facultades)
  static const Color railBg = Color(0xFFF1F5F9);

  /// Bordes táctiles sutiles (width: 0.8 a 1.0)
  static const Color subtleBorder = Color(0xFFE2E8F0);

  /// Superficie blanca limpia de tarjetas y barras
  static const Color cardBg = Colors.white;

  /// Gradiente activo de "En Llamas"
  static const LinearGradient hotFlameGradient = LinearGradient(
    colors: [Color(0xFFFF512F), Color(0xFFF09819)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Sombra suave para barras de filtros y encabezados
  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  /// Sombra suave de píldora "En Llamas"
  static List<BoxShadow> get hotFlameShadow => [
        BoxShadow(
          color: const Color(0xFFFF512F).withValues(alpha: 0.28),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
}
