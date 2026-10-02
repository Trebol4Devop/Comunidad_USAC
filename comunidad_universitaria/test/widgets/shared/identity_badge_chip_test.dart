import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/shared/widgets/identity_badge_chip.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('IdentityBadgeChip Tests', () {
    testWidgets('Modo forumAnonymous muestra seudónimo y badge de privacidad', (tester) async {
      bool switched = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: IdentityBadgeChip(
              mode: IdentityMode.forumAnonymous,
              displayName: 'Estudiante Rebelde #404',
              onSwitchIdentity: () {
                switched = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.masks_outlined), findsOneWidget);
      expect(find.text('Publicando como: '), findsOneWidget);
      expect(find.text('Estudiante Rebelde #404'), findsOneWidget);
      expect(find.text('Modo Anónimo · Identidad protegida'), findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget);

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(switched, isTrue);
    });

    testWidgets('Modo marketplaceVerified sin verificar muestra contacto directo y botón Validar Carné', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: IdentityBadgeChip(
              mode: IdentityMode.marketplaceVerified,
              displayName: 'Emprendedor Sancarlista',
              isVerified: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
      expect(find.text('Publicando con tu perfil: '), findsOneWidget);
      expect(find.text('Emprendedor Sancarlista'), findsOneWidget);
      expect(find.text('Perfil estudiantil de contacto directo'), findsOneWidget);
      expect(find.text('Verificado'), findsNothing);
    });

    testWidgets('Modo marketplaceVerified verificado muestra badge de Verificado e icono check', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: IdentityBadgeChip(
              mode: IdentityMode.marketplaceVerified,
              displayName: 'Carlos Mario Gómez',
              carne: '202100123',
              isVerified: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.verified), findsOneWidget);
      expect(find.text('Carlos Mario Gómez'), findsOneWidget);
      expect(find.text('Verificado'), findsOneWidget);
      expect(find.text('Identidad validada con carné institucional USAC'), findsOneWidget);
    });
  });
}
