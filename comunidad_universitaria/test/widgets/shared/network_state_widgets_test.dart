import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/shared/widgets/network_state_widgets.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('NetworkStateWidgets Tests', () {
    testWidgets('SkeletonCard renderiza con altura personalizada en modo claro y oscuro', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SkeletonCard(height: 140),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonCard), findsOneWidget);

      // Renderiza en modo oscuro
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: const Scaffold(
            body: SkeletonCard(height: 140),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonCard), findsOneWidget);
    });

    testWidgets('OfflineBanner muestra texto de sin conexión y botón reintentar funcional', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: OfflineBanner(
              onRetry: () {
                retried = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.text('Sin conexión. Mostrando contenido en caché.'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Reintentar'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Reintentar'));
      await tester.pumpAndSettle();

      expect(retried, isTrue);
    });
  });
}
