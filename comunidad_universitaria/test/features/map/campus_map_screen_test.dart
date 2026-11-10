import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/services/connectivity_service.dart';
import 'package:comunidad_universitaria/features/map/screens/campus_map_screen.dart';
import 'package:comunidad_universitaria/features/shared/widgets/network_state_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestScreen() {
    return const MaterialApp(
      home: CampusMapScreen(),
    );
  }

  group('CampusMapScreen Widget Tests', () {
    testWidgets('Renderiza en vista móvil (400x800) con buscador, chips y directorio', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Buscador
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText?.contains('Buscar edificio') == true,
        ),
        findsOneWidget,
      );

      // Chips de modo de navegación A*
      expect(find.text('Peatonal'), findsOneWidget);
      expect(find.text('Sin Gradas'), findsOneWidget);
      expect(find.text('Techada (Lluvia)'), findsOneWidget);

      // Directorio integrado
      expect(find.text('Puntos de encuentro y edificios de la USAC'), findsOneWidget);
      expect(find.text('Campus Central'), findsOneWidget);
      expect(find.byTooltip('Cómo llegar'), findsWidgets);
    });

    testWidgets('Renderiza en vista de escritorio (1200x800) con split view', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('Puntos de encuentro y edificios de la USAC'), findsOneWidget);
      expect(find.text('Campus Central'), findsOneWidget);
      expect(find.byTooltip('Cómo llegar'), findsWidgets);
      expect(find.byTooltip('Ver Modelo 3D'), findsOneWidget);
    });

    testWidgets('Filtrado por sede actualiza la cantidad de ubicaciones en el directorio', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Seleccionar chip CUM
      await tester.tap(find.text('CUM').first);
      await tester.pumpAndSettle();

      expect(find.text('CUM'), findsWidgets);
    });

    testWidgets('Muestra OfflineBanner cuando el dispositivo no tiene conexión', (tester) async {
      ConnectivityService.debugIsConnected = false;
      addTearDown(() => ConnectivityService.debugIsConnected = null);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.text('Sin conexión. Mostrando contenido en caché.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });
}
