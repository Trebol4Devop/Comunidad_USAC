import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/shared/widgets/empty_state_widget.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestWidget({
    IconData icon = Icons.forum_outlined,
    String title = 'Sin publicaciones',
    String description = 'Aún no hay mensajes en este canal.',
    String? buttonText,
    VoidCallback? onButtonPressed,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: EmptyStateWidget(
          icon: icon,
          title: title,
          description: description,
          buttonText: buttonText,
          onButtonPressed: onButtonPressed,
        ),
      ),
    );
  }

  group('EmptyStateWidget Tests', () {
    testWidgets('Renderiza icono, título y descripción sin botón cuando no se provee', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          icon: Icons.inbox,
          title: 'Bandeja vacía',
          description: 'No hay elementos para mostrar en este momento.',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('Bandeja vacía'), findsOneWidget);
      expect(find.text('No hay elementos para mostrar en este momento.'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('Muestra botón de acción y responde al tap cuando se configuran', (tester) async {
      bool buttonClicked = false;

      await tester.pumpWidget(
        buildTestWidget(
          icon: Icons.storefront,
          title: 'Sin artículos',
          description: 'Sé el primero en publicar un producto o tutoría.',
          buttonText: 'Crear Anuncio',
          onButtonPressed: () {
            buttonClicked = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.storefront), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Crear Anuncio'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear Anuncio'));
      await tester.pumpAndSettle();

      expect(buttonClicked, isTrue);
    });
  });
}
