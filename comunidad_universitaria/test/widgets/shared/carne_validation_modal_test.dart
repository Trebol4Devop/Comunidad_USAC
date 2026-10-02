import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/user_profile.dart';
import 'package:comunidad_universitaria/features/profile/widgets/carne_validation_modal.dart';
import '../../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestModal({
    UserProfile? currentProfile,
    Function(UserProfile)? onProfileUpdated,
  }) {
    final profile = currentProfile ??
        UserProfile(
          userId: 'user-123',
          alias: 'Estudiante #101',
          facultadId: '08',
          carreraId: 'sistemas',
          sedeId: 'central',
        );

    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: CarneValidationModal(
          currentProfile: profile,
          onProfileUpdated: onProfileUpdated ?? (_) {},
        ),
      ),
    );
  }

  group('CarneValidationModal Widget Tests', () {
    testWidgets('Renderiza en vista móvil (400x800) con campos y caja de privacidad', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      expect(find.text('Validación Estudiantil con Carné'), findsOneWidget);
      expect(find.text('Verificación institucional de confianza'), findsOneWidget);
      expect(find.text('Consentimiento de Privacidad'), findsOneWidget);

      expect(find.widgetWithText(TextFormField, 'Número de Carné Universitario'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nombre Completo Oficial'), findsOneWidget);

      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Validar con Registro'), findsOneWidget);
    });

    testWidgets('Valida carné obligatorio y longitud mínima', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      final validateBtn = find.text('Validar con Registro');
      await tester.tap(validateBtn);
      await tester.pumpAndSettle();

      expect(find.text('Ingresa tu número de carné.'), findsOneWidget);
      expect(find.text('Ingresa tu nombre completo oficial.'), findsOneWidget);

      // Carné menor a 6 dígitos
      final carneField = find.widgetWithText(TextFormField, 'Número de Carné Universitario');
      await tester.enterText(carneField, '1234');
      await tester.tap(validateBtn);
      await tester.pumpAndSettle();

      expect(find.text('El carné debe tener al menos 6 dígitos.'), findsOneWidget);
    });

    testWidgets('Exige consentimiento activo para proceder con la validación', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      // Llenamos campos válidos
      final carneField = find.widgetWithText(TextFormField, 'Número de Carné Universitario');
      await tester.enterText(carneField, '202100123');

      final nameField = find.widgetWithText(TextFormField, 'Nombre Completo Oficial');
      await tester.enterText(nameField, 'Carlos Estudiante');

      // Desmarcamos el consentimiento
      final checkbox = find.byType(Checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Intentamos validar
      final validateBtn = find.text('Validar con Registro');
      await tester.tap(validateBtn);
      await tester.pumpAndSettle();

      expect(find.text('Debes aceptar los términos de verificación informada.'), findsOneWidget);
    });
  });
}
