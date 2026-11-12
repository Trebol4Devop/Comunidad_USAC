import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/shared/widgets/auth_modal.dart';
import '../../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestModal({
    String? title,
    String? subtitle,
    VoidCallback? onAuthenticated,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: AuthModal(
          title: title ?? 'Inicia Sesión para Publicar',
          subtitle:
              subtitle ?? 'Para proteger la comunidad, debes iniciar sesión.',
          onAuthenticated: onAuthenticated ?? () {},
        ),
      ),
    );
  }

  group('AuthModal Widget Tests (Google Only)', () {
    testWidgets(
      'Renderiza en vista móvil (400x800) exclusivamente con inicio de sesión de Google',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestModal());
        await tester.pumpAndSettle();

        expect(find.text('Inicia Sesión para Publicar'), findsOneWidget);
        expect(
          find.text('Para proteger la comunidad, debes iniciar sesión.'),
          findsOneWidget,
        );

        // Botón Google visible
        expect(find.text('Continuar con Google'), findsOneWidget);

        // Campos de correo y contraseña NO deben existir
        expect(find.text('o con correo'), findsNothing);
        expect(find.widgetWithText(TextFormField, 'Correo electrónico'), findsNothing);
        expect(find.widgetWithText(TextFormField, 'Contraseña'), findsNothing);
        expect(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'), findsNothing);
        expect(find.text('¿No tienes cuenta? Regístrate aquí'), findsNothing);
        expect(find.text('¿Ya tienes cuenta? Inicia sesión'), findsNothing);
      },
    );

    testWidgets(
      'Renderiza en vista escritorio (1200x800) exclusivamente con inicio de sesión de Google',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestModal());
        await tester.pumpAndSettle();

        expect(find.text('Continuar con Google'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
      },
    );

    testWidgets('No ofrece formulario de contraseña ni recuperación por correo', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      expect(find.text('¿Olvidaste tu contraseña?'), findsNothing);
      expect(find.text('Enviar código de recuperación'), findsNothing);
      expect(find.text('Continuar con Google'), findsOneWidget);
    });
  });
}
