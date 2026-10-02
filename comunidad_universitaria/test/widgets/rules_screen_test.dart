import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/rules/screens/rules_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestRules({bool isDarkMode = false}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const RulesScreen(),
    );
  }

  group('RulesScreen Widget Tests', () {
    testWidgets('Renderiza en pantalla móvil (400x800) sin desbordamientos', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestRules());
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Normas Comunitarias & Descargo Legal'), findsOneWidget);
      expect(
        find.textContaining('iniciativa estudiantil independiente'),
        findsOneWidget,
      );

      // Títulos de secciones
      expect(find.text('Reglas de Convivencia Estudiantil'), findsOneWidget);
      expect(find.text('Normas del Marketplace & Servicios Estudiantiles'), findsOneWidget);
      expect(find.text('Descargo de Responsabilidad Legal e Independencia'), findsOneWidget);
      expect(find.text('Portales Oficiales de Unidades Académicas'), findsOneWidget);
    });

    testWidgets('Renderiza en pantalla de escritorio (1200x800) en modo oscuro', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestRules(isDarkMode: true));
      await tester.pumpAndSettle();

      expect(find.text('Normas Comunitarias & Descargo Legal'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsWidgets);
    });

    testWidgets('Muestra las 7 reglas comunitarias numeradas', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestRules());
      await tester.pumpAndSettle();

      // Verificar números de reglas
      for (int i = 1; i <= 7; i++) {
        expect(find.text('$i'), findsOneWidget);
      }

      // Verificar títulos de reglas
      expect(find.text('Respeto mutuo y fraternidad universitaria'), findsOneWidget);
      expect(find.text('Veracidad y enlaces limpios'), findsOneWidget);
      expect(find.text('Prohibición de venta de exámenes o fraude académico'), findsOneWidget);
      expect(find.text('Protección de Privacidad y Seudónimos'), findsOneWidget);
      expect(find.text('Trato directo y sin intermediación financiera'), findsOneWidget);
      expect(find.text('Prohibición estricta de sustancias y productos ilegales'), findsOneWidget);
      expect(find.text('Seguridad en puntos de encuentro'), findsOneWidget);
    });

    testWidgets('Muestra los chips de las unidades académicas / facultades oficiales', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestRules());
      await tester.pumpAndSettle();

      // Action chips de facultades
      expect(find.byType(ActionChip), findsWidgets);
      expect(find.widgetWithText(ActionChip, 'Facultad de Ingeniería'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Facultad de Ciencias Económicas'), findsOneWidget);
    });
  });
}
