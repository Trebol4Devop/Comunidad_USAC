import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/user_profile.dart';
import 'package:comunidad_universitaria/core/services/profile_service.dart';
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
    final profile =
        currentProfile ??
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
    testWidgets(
      'Renderiza en vista móvil con consentimiento desmarcado y bloqueo explícito',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestModal());
        await tester.pumpAndSettle();

        expect(find.text('Datos para verificación de carné'), findsOneWidget);
        expect(find.text('Sin fuente institucional conectada'), findsOneWidget);
        expect(
          find.text('Consentimiento para guardar un borrador'),
          findsOneWidget,
        );
        expect(
          find.textContaining('no se hará ninguna consulta'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextFormField, 'Número de Carné Universitario'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextFormField, 'Nombre completo para reintentar'),
          findsOneWidget,
        );
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
        expect(find.text('Cancelar'), findsOneWidget);
        expect(find.text('Guardar borrador'), findsOneWidget);
      },
    );

    testWidgets('Valida carné obligatorio y longitud mínima', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      final saveButton = find.text('Guardar borrador');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Ingresa tu número de carné.'), findsOneWidget);
      expect(find.text('Ingresa tu nombre completo.'), findsOneWidget);

      final carneField = find.widgetWithText(
        TextFormField,
        'Número de Carné Universitario',
      );
      await tester.enterText(carneField, '1234');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(
        find.text('El carné debe tener al menos 6 dígitos.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'No guarda los datos si el consentimiento explícito no está marcado',
      (tester) async {
        tester.view.physicalSize = const Size(600, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestModal());
        await tester.pumpAndSettle();

        final carneField = find.widgetWithText(
          TextFormField,
          'Número de Carné Universitario',
        );
        final nameField = find.widgetWithText(
          TextFormField,
          'Nombre completo para reintentar',
        );
        await tester.enterText(carneField, '202100123');
        await tester.enterText(nameField, 'Carlos Estudiante');
        await tester.tap(find.text('Guardar borrador'));
        await tester.pumpAndSettle();

        expect(
          find.text('Debes autorizar el guardado local antes de continuar.'),
          findsOneWidget,
        );
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
        expect(
          tester.widget<TextFormField>(carneField).controller!.text,
          '202100123',
        );
        expect(
          tester.widget<TextFormField>(nameField).controller!.text,
          'Carlos Estudiante',
        );

        final savedProfile = await ProfileService.loadProfile();
        expect(savedProfile.carne, isNull);
        expect(savedProfile.studentName, isNull);
        expect(savedProfile.isCarneVerified, isFalse);
      },
    );

    testWidgets(
      'Guarda un borrador no verificado y conserva los datos para reintentar',
      (tester) async {
        tester.view.physicalSize = const Size(600, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        UserProfile? profileFromCallback;
        final previouslyVerifiedProfile = UserProfile(
          userId: 'user-123',
          alias: 'Estudiante #101',
          carne: '199900001',
          studentName: 'Nombre previo',
          isCarneVerified: true,
        );

        await tester.pumpWidget(
          buildTestModal(
            currentProfile: previouslyVerifiedProfile,
            onProfileUpdated: (updated) => profileFromCallback = updated,
          ),
        );
        await tester.pumpAndSettle();

        final carneField = find.widgetWithText(
          TextFormField,
          'Número de Carné Universitario',
        );
        final nameField = find.widgetWithText(
          TextFormField,
          'Nombre completo para reintentar',
        );
        await tester.enterText(carneField, '202100123');
        await tester.enterText(nameField, 'Carlos Estudiante');

        final checkbox = find.byType(Checkbox);
        expect(tester.widget<Checkbox>(checkbox).value, isFalse);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(checkbox).value, isTrue);

        await tester.tap(find.text('Guardar borrador'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Borrador guardado en este dispositivo.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('tu condición estudiantil no está verificada.'),
          findsOneWidget,
        );
        expect(find.text('Guardar borrador'), findsOneWidget);
        expect(profileFromCallback?.carne, '202100123');
        expect(profileFromCallback?.studentName, 'Carlos Estudiante');
        expect(profileFromCallback?.isCarneVerified, isFalse);
        expect(
          tester.widget<TextFormField>(carneField).controller!.text,
          '202100123',
        );
        expect(
          tester.widget<TextFormField>(nameField).controller!.text,
          'Carlos Estudiante',
        );

        final savedProfile = await ProfileService.loadProfile();
        expect(savedProfile.carne, '202100123');
        expect(savedProfile.studentName, 'Carlos Estudiante');
        expect(savedProfile.isCarneVerified, isFalse);

        await tester.pumpWidget(buildTestModal(currentProfile: savedProfile));
        await tester.pumpAndSettle();

        final retriedCarneField = find.widgetWithText(
          TextFormField,
          'Número de Carné Universitario',
        );
        final retriedNameField = find.widgetWithText(
          TextFormField,
          'Nombre completo para reintentar',
        );
        expect(
          tester.widget<TextFormField>(retriedCarneField).controller!.text,
          '202100123',
        );
        expect(
          tester.widget<TextFormField>(retriedNameField).controller!.text,
          'Carlos Estudiante',
        );
        expect(savedProfile.isCarneVerified, isFalse);
      },
    );
  });
}
