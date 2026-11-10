import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:usac_campus_map/usac_campus_map.dart';

/// Modelo de datos para la representación tridimensional e isométrica de un edificio universitario.
class UsacBuilding3DModel {
  final String id;
  final String name;
  final int floorsCount;
  final String category;
  final List<List<double>> polygonCoordinates;

  const UsacBuilding3DModel({
    required this.id,
    required this.name,
    required this.floorsCount,
    required this.category,
    this.polygonCoordinates = const [],
  });

  factory UsacBuilding3DModel.fromBuilding(CampusBuilding building) {
    return UsacBuilding3DModel(
      id: building.id,
      name: building.name,
      floorsCount: building.floorsCount > 0 ? building.floorsCount : 1,
      category: building.category,
      polygonCoordinates: building.polygon
          .map((coord) => [coord.latitude, coord.longitude])
          .toList(),
    );
  }
}

/// Visor volumétrico 3D / isométrico interactivo con soporte de rotación y zoom táctil.
class Building3DViewer extends StatefulWidget {
  final UsacBuilding3DModel model;
  final UsacMapTheme theme;

  const Building3DViewer({
    super.key,
    required this.model,
    required this.theme,
  });

  @override
  State<Building3DViewer> createState() => _Building3DViewerState();
}

class _Building3DViewerState extends State<Building3DViewer> {
  double _rotationAngle = -0.55; // Ángulo de rotación horizontal
  double _tiltAngle = 0.65;      // Inclinación vertical isométrica
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _rotationAngle += details.delta.dx * 0.01;
              _tiltAngle = (_tiltAngle - details.delta.dy * 0.01).clamp(0.2, 1.2);
            });
          },
          child: InteractiveViewer(
            minScale: 0.7,
            maxScale: 2.5,
            onInteractionUpdate: (details) {
              if (details.scale != 1.0) {
                setState(() {
                  _scale = details.scale.clamp(0.7, 2.5);
                });
              }
            },
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: CustomPaint(
                painter: _IsometricBuildingPainter(
                  model: widget.model,
                  theme: widget.theme,
                  rotationAngle: _rotationAngle,
                  tiltAngle: _tiltAngle,
                  zoomScale: _scale,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IsometricBuildingPainter extends CustomPainter {
  final UsacBuilding3DModel model;
  final UsacMapTheme theme;
  final double rotationAngle;
  final double tiltAngle;
  final double zoomScale;

  _IsometricBuildingPainter({
    required this.model,
    required this.theme,
    required this.rotationAngle,
    required this.tiltAngle,
    required this.zoomScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 30);
    final floors = model.floorsCount;
    final floorHeight = 22.0 * zoomScale;
    final baseWidth = 140.0 * zoomScale;
    final baseDepth = 90.0 * zoomScale;

    final cosR = math.cos(rotationAngle);
    final sinR = math.sin(rotationAngle);
    final sinT = math.sin(tiltAngle);

    // Función de proyección 3D isométrica a 2D canvas
    Offset project(double x, double y, double z) {
      final rotX = x * cosR - y * sinR;
      final rotY = x * sinR + y * cosR;
      final px = center.dx + rotX;
      final py = center.dy + (rotY * sinT) - (z * 1.0);
      return Offset(px, py);
    }

    final fillPaint = Paint()
      ..color = theme.primaryColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    final topPaint = Paint()
      ..color = theme.primaryColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final accentPaint = Paint()
      ..color = theme.accentColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = theme.buildingBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final gridPaint = Paint()
      ..color = theme.buildingBorderColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Dibujar cuadrícula de terreno en la base
    final groundPath = Path();
    const groundSize = 190.0;
    groundPath.moveTo(project(-groundSize, -groundSize, 0).dx, project(-groundSize, -groundSize, 0).dy);
    groundPath.lineTo(project(groundSize, -groundSize, 0).dx, project(groundSize, -groundSize, 0).dy);
    groundPath.lineTo(project(groundSize, groundSize, 0).dx, project(groundSize, groundSize, 0).dy);
    groundPath.lineTo(project(-groundSize, groundSize, 0).dx, project(-groundSize, groundSize, 0).dy);
    groundPath.close();
    canvas.drawPath(groundPath, gridPaint);

    // 2. Dibujar cada nivel o estrato del edificio
    for (int i = 0; i < floors; i++) {
      final zBottom = i * floorHeight;
      final zTop = (i + 1) * floorHeight;

      final p1Bottom = project(-baseWidth / 2, -baseDepth / 2, zBottom);
      final p2Bottom = project(baseWidth / 2, -baseDepth / 2, zBottom);
      final p3Bottom = project(baseWidth / 2, baseDepth / 2, zBottom);
      final p4Bottom = project(-baseWidth / 2, baseDepth / 2, zBottom);

      final p1Top = project(-baseWidth / 2, -baseDepth / 2, zTop);
      final p2Top = project(baseWidth / 2, -baseDepth / 2, zTop);
      final p3Top = project(baseWidth / 2, baseDepth / 2, zTop);
      final p4Top = project(-baseWidth / 2, baseDepth / 2, zTop);

      // Caras laterales visibles
      final wallPath = Path();
      wallPath.moveTo(p1Bottom.dx, p1Bottom.dy);
      wallPath.lineTo(p2Bottom.dx, p2Bottom.dy);
      wallPath.lineTo(p2Top.dx, p2Top.dy);
      wallPath.lineTo(p1Top.dx, p1Top.dy);
      wallPath.close();
      canvas.drawPath(wallPath, fillPaint);
      canvas.drawPath(wallPath, strokePaint);

      final sidePath = Path();
      sidePath.moveTo(p2Bottom.dx, p2Bottom.dy);
      sidePath.lineTo(p3Bottom.dx, p3Bottom.dy);
      sidePath.lineTo(p3Top.dx, p3Top.dy);
      sidePath.lineTo(p2Top.dx, p2Top.dy);
      sidePath.close();
      canvas.drawPath(sidePath, fillPaint);
      canvas.drawPath(sidePath, strokePaint);

      final frontPath = Path();
      frontPath.moveTo(p4Bottom.dx, p4Bottom.dy);
      frontPath.lineTo(p3Bottom.dx, p3Bottom.dy);
      frontPath.lineTo(p3Top.dx, p3Top.dy);
      frontPath.lineTo(p4Top.dx, p4Top.dy);
      frontPath.close();
      canvas.drawPath(frontPath, fillPaint);
      canvas.drawPath(frontPath, strokePaint);

      // Cara superior (techo de cada nivel o losa superior)
      final floorLosa = Path();
      floorLosa.moveTo(p1Top.dx, p1Top.dy);
      floorLosa.lineTo(p2Top.dx, p2Top.dy);
      floorLosa.lineTo(p3Top.dx, p3Top.dy);
      floorLosa.lineTo(p4Top.dx, p4Top.dy);
      floorLosa.close();

      canvas.drawPath(floorLosa, i == floors - 1 ? topPaint : fillPaint);
      canvas.drawPath(floorLosa, strokePaint);

      // Distintivo de entrada o acento sancarlista en nivel 1
      if (i == 0) {
        final doorPath = Path();
        final d1 = project(-18 * zoomScale, baseDepth / 2 + 1, 0);
        final d2 = project(18 * zoomScale, baseDepth / 2 + 1, 0);
        final d3 = project(18 * zoomScale, baseDepth / 2 + 1, 14 * zoomScale);
        final d4 = project(-18 * zoomScale, baseDepth / 2 + 1, 14 * zoomScale);
        doorPath.moveTo(d1.dx, d1.dy);
        doorPath.lineTo(d2.dx, d2.dy);
        doorPath.lineTo(d3.dx, d3.dy);
        doorPath.lineTo(d4.dx, d4.dy);
        doorPath.close();
        canvas.drawPath(doorPath, accentPaint);
        canvas.drawPath(doorPath, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _IsometricBuildingPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.tiltAngle != tiltAngle ||
        oldDelegate.zoomScale != zoomScale ||
        oldDelegate.model != model;
  }
}
