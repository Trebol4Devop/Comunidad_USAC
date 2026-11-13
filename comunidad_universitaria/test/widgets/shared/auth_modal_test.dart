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

  group('AuthModal Widget Tests', () {
    testWidgets('muestra Google y correo/contraseña en vista móvil', (
      tester,
    ) async {
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

      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.text('o con correo'), findsOneWidget);
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.text('Continuar con TOTP'), findsNothing);
      expect(find.text('Verificar código TOTP'), findsNothing);
      expect(find.text('¿No tienes cuenta? Regístrate'), findsOneWidget);
    });

    testWidgets('muestra las dos opciones en vista escritorio', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });

    testWidgets('permite cambiar entre iniciar sesión y crear cuenta', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.text('¿Olvidaste tu contraseña?'), findsNothing);
      expect(find.text('Enviar código de recuperación'), findsNothing);

      await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
      await tester.pumpAndSettle();
      expect(find.text('Crear cuenta'), findsOneWidget);
      expect(find.text('¿Ya tienes cuenta? Inicia sesión'), findsOneWidget);

      await tester.tap(find.text('¿Ya tienes cuenta? Inicia sesión'));
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });
  });
}
