import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/shared/widgets/image_viewer_dialog.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestDialog({
    String imageUrl = 'https://example.com/imagen.jpg',
    String? title,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ImageViewerDialog(
          imageUrl: imageUrl,
          title: title,
        ),
      ),
    );
  }

  group('ImageViewerDialog Tests', () {
    testWidgets('Renderiza InteractiveViewer y botón de cerrar', (tester) async {
      await tester.pumpWidget(buildTestDialog(imageUrl: 'https://example.com/foto.png'));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byTooltip('Cerrar visor'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('Muestra badge con título cuando se provee', (tester) async {
      await tester.pumpWidget(
        buildTestDialog(
          imageUrl: 'https://example.com/mapa.png',
          title: 'Mapa del Campus Central',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mapa del Campus Central'), findsOneWidget);
    });
  });
}
