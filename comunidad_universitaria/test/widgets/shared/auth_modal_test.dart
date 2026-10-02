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
          subtitle: subtitle ?? 'Para proteger la comunidad, debes iniciar sesión.',
          onAuthenticated: onAuthenticated ?? () {},
        ),
      ),
    );
  }

  group('AuthModal Widget Tests', () {
    testWidgets('Renderiza en vista móvil (400x800) con campos y opciones de login', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      expect(find.text('Inicia Sesión para Publicar'), findsOneWidget);
      expect(find.text('Para proteger la comunidad, debes iniciar sesión.'), findsOneWidget);

      // Botón Google
      expect(find.text('Continuar con Google'), findsOneWidget);
      expect(find.text('o con correo'), findsOneWidget);

      // Campos de texto
      expect(find.widgetWithText(TextFormField, 'Correo electrónico'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Contraseña'), findsOneWidget);

      // Botón de submit y toggle
      expect(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'), findsOneWidget);
      expect(find.text('¿No tienes cuenta? Regístrate aquí'), findsOneWidget);
    });

    testWidgets('Alterna entre Iniciar Sesión y Crear Cuenta', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      final toggleBtn = find.text('¿No tienes cuenta? Regístrate aquí');
      expect(toggleBtn, findsOneWidget);

      // Cambiar a modo registro
      await tester.tap(toggleBtn);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Crear Cuenta y Publicar'), findsOneWidget);
      expect(find.text('¿Ya tienes cuenta? Inicia sesión'), findsOneWidget);

      // Volver a modo login
      await tester.tap(find.text('¿Ya tienes cuenta? Inicia sesión'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'), findsOneWidget);
    });

    testWidgets('Valida formato de correo y longitud de contraseña', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      // Submit con campos vacíos
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un correo válido'), findsOneWidget);
      expect(find.text('La contraseña debe tener al menos 6 caracteres'), findsOneWidget);

      // Correo inválido sin @
      final emailField = find.widgetWithText(TextFormField, 'Correo electrónico');
      await tester.enterText(emailField, 'correousac.gt');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un correo válido'), findsOneWidget);

      // Correo válido y contraseña corta
      await tester.enterText(emailField, 'estudiante@usac.edu.gt');
      final passField = find.widgetWithText(TextFormField, 'Contraseña');
      await tester.enterText(passField, '12345');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un correo válido'), findsNothing);
      expect(find.text('La contraseña debe tener al menos 6 caracteres'), findsOneWidget);
    });
  });
}
