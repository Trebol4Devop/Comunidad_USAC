import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:comunidad_universitaria/core/services/groups_service.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import 'helpers/app_launcher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: Flujo Real de Grupos Estudiantiles (Crear / Leer / Borrar)', () {
    testWidgets(
      'Crea un grupo de WhatsApp/Telegram, alterna upvotes y lo elimina',
      skip: !isLocalSupabaseConfigured,
      (tester) async {
        final uniqueTitle = 'Grupo E2E Física 1 ${DateTime.now().millisecondsSinceEpoch}';

        await launchApp(tester, surfaceSize: const Size(400, 800));

        // Navegar a pestaña de Grupos
        await tester.tap(find.text('Grupos'));
        await tester.pumpAndSettle();

        // 1. Crear grupo estudiantil
        final group = await GroupsService.createGroup(
          title: uniqueTitle,
          carrera: 'sistemas',
          curso: 'Física 1',
          section: 'B+',
          link: 'https://chat.whatsapp.com/testfisica1',
          description: 'Grupo creado por prueba E2E de integración.',
          authorAlias: 'E2E Group Tester',
        );

        expect(group, isNotNull);
        expect(group!.id, isNotEmpty);

        // 2. Consultar grupos activos
        final groups = await GroupsService.fetchGroups(carrera: 'sistemas');
        expect(groups.any((g) => g.id == group.id), isTrue);

        // 3. Alternar upvote (quita el auto-upvote del creador)
        final toggledOff = await GroupsService.toggleUpvote(group);
        expect(toggledOff, isFalse);

        // El modelo WhatsAppGroup es inmutable: hay que releer el grupo para
        // obtener el estado real (isUpvotedByMe = false) antes de volver a
        // alternar; si no, el segundo toggle intentaría quitar de nuevo.
        final refreshed = (await GroupsService.fetchGroups(carrera: 'sistemas'))
            .firstWhere((g) => g.id == group.id);
        expect(refreshed.isUpvotedByMe, isFalse);

        final toggledOn = await GroupsService.toggleUpvote(refreshed);
        expect(toggledOn, isTrue);

        // 4. Limpieza en base de datos
        await SupabaseService.client
            .from('student_group_upvotes')
            .delete()
            .eq('group_id', group.id);

        await SupabaseService.client
            .from('student_groups')
            .delete()
            .eq('id', group.id);

        final check = await SupabaseService.client
            .from('student_groups')
            .select('id')
            .eq('id', group.id);

        expect((check as List).isEmpty, isTrue);
      },
    );
  });
}
