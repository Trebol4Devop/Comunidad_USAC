import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/features/verification/models/verification_status.dart';
import 'package:comunidad_universitaria/features/verification/state/verification_controller.dart';
import 'package:comunidad_universitaria/features/verification/widgets/verification_banner.dart';
import 'package:comunidad_universitaria/features/verification/widgets/verification_gate.dart';

void main() {
  group('VerificationGate Widget Tests', () {
    late VerificationController controller;

    setUp(() {
      controller = VerificationController(listenToAuthChanges: false);
    });

    tearDown(() {
      controller.dispose();
    });

    Widget createTestWidget({
      required VerificationController controller,
      VoidCallback? onRetry,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: VerificationGate(
            controller: controller,
            onRetryVerification: onRetry,
            child: const Center(
              child: Text('Vista de AppShell'),
            ),
          ),
        ),
      );
    }

    testWidgets('Muestra banner informativo en estado pending_review sin CTA de reintento', (tester) async {
      controller.setStatus(StudentVerificationStatus.pendingReview);

      await tester.pumpWidget(createTestWidget(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byType(VerificationBanner), findsOneWidget);
      expect(
        find.text('Tu verificación está en revisión. Podrás publicar en el Marketplace en breve.'),
        findsOneWidget,
      );
      // No debe mostrar botón de reintentar mientras esté en revisión
      expect(find.text('Reintentar verificación'), findsNothing);
      expect(find.text('Vista de AppShell'), findsOneWidget);
    });

    testWidgets('Muestra banner de advertencia y botón CTA en estado rejected', (tester) async {
      bool retryPressed = false;
      controller.setStatus(
        StudentVerificationStatus.rejected,
        reason: 'Foto del documento demasiado oscura.',
      );

      await tester.pumpWidget(
        createTestWidget(
          controller: controller,
          onRetry: () => retryPressed = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VerificationBanner), findsOneWidget);
      expect(
        find.text('Verificación rechazada: Foto del documento demasiado oscura.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar verificación'), findsOneWidget);

      // Pulsar CTA de reintento
      await tester.tap(find.text('Reintentar verificación'));
      await tester.pumpAndSettle();

      expect(retryPressed, isTrue);
    });

    testWidgets('No muestra banner en estado verified y permite acceso completo', (tester) async {
      controller.setStatus(StudentVerificationStatus.verified);

      await tester.pumpWidget(createTestWidget(controller: controller));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Tu verificación está en revisión'),
        findsNothing,
      );
      expect(
        find.textContaining('Verificación rechazada'),
        findsNothing,
      );
      expect(find.text('Reintentar verificación'), findsNothing);
      expect(find.text('Vista de AppShell'), findsOneWidget);
    });

    testWidgets('Acceso de invitado y permisos de escritura en VerificationGate', (tester) async {
      // En estado unverified o invitado, canPublish debe ser false
      controller.setStatus(StudentVerificationStatus.unverified);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VerificationGate(
              controller: controller,
              child: Builder(
                builder: (context) {
                  final canPublish = VerificationGate.canPublish(context);
                  final isGuest = VerificationGate.isGuest(context);

                  return Column(
                    children: [
                      if (canPublish)
                        const ElevatedButton(
                          onPressed: null,
                          child: Text('Acción de Publicar'),
                        )
                      else
                        const Text('Publicación Bloqueada para No Verificados'),
                      Text('Estado Invitado: $isGuest'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acción de Publicar'), findsNothing);
      expect(find.text('Publicación Bloqueada para No Verificados'), findsOneWidget);
    });
  });
}
