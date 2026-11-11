import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/shared/widgets/gif_picker_modal.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestModal({
    Function(String)? onGifSelected,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: GifPickerModal(
          onGifSelected: onGifSelected ?? (_) {},
        ),
      ),
    );
  }

  group('GifPickerModal Tests', () {
    testWidgets('Renderiza buscador, categorías chips y lista de gifs', (tester) async {
      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      expect(find.text('Insertar GIF o Sticker'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Buscar GIFs...'), findsOneWidget);

      // Categorías
      expect(find.text('Populares'), findsOneWidget);
      expect(find.text('Estudiando'), findsOneWidget);
      expect(find.text('Parciales'), findsOneWidget);
      expect(find.text('Aprobado'), findsOneWidget);

      // GIFs de la categoría todas
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('Lofi Cat Estudiando'), findsOneWidget);
    });

    testWidgets('Filtrar por texto muestra resultados o mensaje de no encontrados', (tester) async {
      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      final searchField = find.widgetWithText(TextField, 'Buscar GIFs...');
      await tester.enterText(searchField, 'Mucho Café');
      await tester.pumpAndSettle();

      expect(find.text('Mucho Café'), findsWidgets);
      expect(find.text('Lofi Cat Estudiando'), findsNothing);

      // Búsqueda sin resultados
      await tester.enterText(searchField, 'TextoQueNoExisteEnLosGifs');
      await tester.pumpAndSettle();

      expect(find.text('No se encontraron GIFs'), findsOneWidget);
    });

    testWidgets('Hacer tap en un GIF dispara callback onGifSelected', (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? selectedUrl;

      await tester.pumpWidget(
        buildTestModal(
          onGifSelected: (url) {
            selectedUrl = url;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Tap en el primer InkWell de la grilla de GIFs
      final gifInkWell = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      ).first;
      await tester.tap(gifInkWell);
      await tester.pumpAndSettle();

      expect(selectedUrl, isNotNull);
      expect(selectedUrl, contains('giphy.gif'));
    });
  });
}
