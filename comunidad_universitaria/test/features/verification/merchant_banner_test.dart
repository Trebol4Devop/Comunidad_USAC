import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/features/verification/models/verification_status.dart';
import 'package:comunidad_universitaria/features/verification/state/verification_controller.dart';
import 'package:comunidad_universitaria/features/verification/widgets/verification_banner.dart';
import '../../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildBannerApp({
    required VerificationController controller,
    VoidCallback? onRetry,
    VoidCallback? onRetryMerchant,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: VerificationBanner(
          controller: controller,
          onRetry: onRetry,
          onRetryMerchant: onRetryMerchant,
        ),
      ),
    );
  }

  group('VerificationBanner Merchant Tests', () {
    late VerificationController controller;

    setUp(() {
      controller = VerificationController(listenToAuthChanges: false);
    });

    testWidgets('Muestra banner de comerciante pendiente', (tester) async {
      controller.setMerchantStatus('pending');

      await tester.pumpWidget(buildBannerApp(controller: controller));
      await tester.pumpAndSettle();

      expect(
        find.text('Tu solicitud de comerciante está en revisión. Podrás publicar cuando sea aprobada.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('Muestra banner de comerciante rechazado con motivo y botón Reintentar', (tester) async {
      bool retryClicked = false;
      controller.setMerchantStatus('rejected', reason: 'La fotografía del establecimiento no es clara');

      await tester.pumpWidget(
        buildBannerApp(
          controller: controller,
          onRetryMerchant: () {
            retryClicked = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Solicitud de comerciante rechazada: La fotografía del establecimiento no es clara'),
        findsOneWidget,
      );

      final retryBtn = find.widgetWithText(TextButton, 'Reintentar');
      expect(retryBtn, findsOneWidget);

      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(retryClicked, isTrue);
    });

    testWidgets('Estudiante verificado sin solicitud de comerciante no muestra ningún banner', (tester) async {
      controller.setStatus(StudentVerificationStatus.verified);
      controller.setMerchantStatus('unverified');

      await tester.pumpWidget(buildBannerApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byType(VerificationBanner), findsOneWidget);
      expect(find.textContaining('revisión'), findsNothing);
      expect(find.textContaining('rechazada'), findsNothing);
    });

    testWidgets('Estudiante verificado y comerciante pendiente muestra banner de comerciante', (tester) async {
      controller.setStatus(StudentVerificationStatus.verified);
      controller.setMerchantStatus('pending');

      await tester.pumpWidget(buildBannerApp(controller: controller));
      await tester.pumpAndSettle();

      expect(
        find.text('Tu solicitud de comerciante está en revisión. Podrás publicar cuando sea aprobada.'),
        findsOneWidget,
      );
    });

    testWidgets('Prioridad: estudiante pendiente prevalece sobre comerciante pendiente', (tester) async {
      controller.setStatus(StudentVerificationStatus.pendingReview);
      controller.setMerchantStatus('pending');

      await tester.pumpWidget(buildBannerApp(controller: controller));
      await tester.pumpAndSettle();

      // Debe mostrar el banner de estudiante pendiente
      expect(
        find.text('Tu verificación está en revisión. Podrás publicar en el Marketplace en breve.'),
        findsOneWidget,
      );
      // No debe mostrar el de comerciante
      expect(
        find.text('Tu solicitud de comerciante está en revisión. Podrás publicar cuando sea aprobada.'),
        findsNothing,
      );
    });
  });
}
