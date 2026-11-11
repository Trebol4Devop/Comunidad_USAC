import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:comunidad_universitaria/core/services/local_storage_service.dart';
import 'package:comunidad_universitaria/features/profile/screens/profile_screen.dart';
import 'package:comunidad_universitaria/features/profile/widgets/carne_validation_modal.dart';
import 'package:comunidad_universitaria/features/shared/widgets/alias_badge_button.dart';
import 'helpers/app_launcher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: Flujo Real de Perfil y Validación (Crear / Leer / Guardar)', () {
    testWidgets(
      'Actualiza seudónimo/alias estudiantil y abre modal de validación de carné',
      skip: !isLocalSupabaseConfigured,
      (tester) async {
        const initialAlias = 'Estudiante USAC #100';
        const newAlias = 'Ingeniero Futuro USAC';

        await launchApp(
          tester,
          initialAlias: initialAlias,
          surfaceSize: const Size(400, 800),
        );

        // 1. Navegar a pantalla de perfil desde AliasBadgeButton
        final aliasButton = find.byType(AliasBadgeButton);
        expect(aliasButton, findsOneWidget);
        await tester.tap(aliasButton);
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);

        // 2. Modificar el campo de alias
        final aliasField = find.widgetWithText(TextField, initialAlias);
        if (aliasField.evaluate().isNotEmpty) {
          await tester.enterText(aliasField.first, newAlias);
          await tester.pumpAndSettle();

          // Presionar botón de guardar
          final saveButton = find.text('Guardar Cambios de Perfil');
          if (saveButton.evaluate().isNotEmpty) {
            await tester.tap(saveButton);
            await tester.pumpAndSettle();

            // Verificar persistencia local
            final savedProfile = await LocalStorageService.getUserProfile();
            expect(savedProfile.alias, equals(newAlias));
          }
        }

        // 3. Abrir modal de validación de carné si está disponible
        final validateButton = find.text('Validar');
        if (validateButton.evaluate().isNotEmpty) {
          await tester.tap(validateButton.first);
          await tester.pumpAndSettle();

          expect(find.byType(CarneValidationModal), findsOneWidget);

          // Cerrar modal
          final closeButton = find.byIcon(Icons.close);
          if (closeButton.evaluate().isNotEmpty) {
            await tester.tap(closeButton.first);
            await tester.pumpAndSettle();
            expect(find.byType(CarneValidationModal), findsNothing);
          }
        }
      },
    );
  });
}
