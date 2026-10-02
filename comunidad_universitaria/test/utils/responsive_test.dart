import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/utils/responsive.dart';

void main() {
  group('Responsive Helper Methods', () {
    testWidgets('Responsive.isMobile detecta anchos menores a 700', (tester) async {
      late bool isMobile;
      late bool isTablet;
      late bool isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(600, 800)),
            child: Builder(
              builder: (context) {
                isMobile = Responsive.isMobile(context);
                isTablet = Responsive.isTablet(context);
                isDesktop = Responsive.isDesktop(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(isMobile, isTrue);
      expect(isTablet, isFalse);
      expect(isDesktop, isFalse);
    });

    testWidgets('Responsive.isTablet detecta anchos entre 700 y 1099', (tester) async {
      late bool isMobile;
      late bool isTablet;
      late bool isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(800, 1000)),
            child: Builder(
              builder: (context) {
                isMobile = Responsive.isMobile(context);
                isTablet = Responsive.isTablet(context);
                isDesktop = Responsive.isDesktop(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(isMobile, isFalse);
      expect(isTablet, isTrue);
      expect(isDesktop, isFalse);
    });

    testWidgets('Responsive.isDesktop detecta anchos mayores o iguales a 1100', (tester) async {
      late bool isMobile;
      late bool isTablet;
      late bool isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 900)),
            child: Builder(
              builder: (context) {
                isMobile = Responsive.isMobile(context);
                isTablet = Responsive.isTablet(context);
                isDesktop = Responsive.isDesktop(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(isMobile, isFalse);
      expect(isTablet, isFalse);
      expect(isDesktop, isTrue);
    });
  });

  group('Responsive Widget Rendering', () {
    Widget buildResponsiveTree({required double width, Widget? tablet}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800)),
          child: Responsive(
            mobile: const Text('MobileView'),
            tablet: tablet,
            desktop: const Text('DesktopView'),
          ),
        ),
      );
    }

    testWidgets('renderiza MobileView cuando ancho < 700', (tester) async {
      await tester.pumpWidget(buildResponsiveTree(width: 500, tablet: const Text('TabletView')));
      expect(find.text('MobileView'), findsOneWidget);
      expect(find.text('TabletView'), findsNothing);
      expect(find.text('DesktopView'), findsNothing);
    });

    testWidgets('renderiza TabletView cuando 700 <= ancho < 1100 y tablet != null', (tester) async {
      await tester.pumpWidget(buildResponsiveTree(width: 850, tablet: const Text('TabletView')));
      expect(find.text('TabletView'), findsOneWidget);
      expect(find.text('MobileView'), findsNothing);
      expect(find.text('DesktopView'), findsNothing);
    });

    testWidgets('renderiza MobileView como fallback en tablet si tablet == null', (tester) async {
      await tester.pumpWidget(buildResponsiveTree(width: 850, tablet: null));
      expect(find.text('MobileView'), findsOneWidget);
      expect(find.text('DesktopView'), findsNothing);
    });

    testWidgets('renderiza DesktopView cuando ancho >= 1100', (tester) async {
      await tester.pumpWidget(buildResponsiveTree(width: 1200, tablet: const Text('TabletView')));
      expect(find.text('DesktopView'), findsOneWidget);
      expect(find.text('TabletView'), findsNothing);
      expect(find.text('MobileView'), findsNothing);
    });
  });

  group('MaxWidthContainer Widget', () {
    testWidgets('renderiza contenido con restricciones y padding configurados', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MaxWidthContainer(
              maxWidth: 900,
              padding: EdgeInsets.all(24),
              child: Text('Contenido Central'),
            ),
          ),
        ),
      );

      expect(find.text('Contenido Central'), findsOneWidget);
      final constrainedBox = tester.widget<ConstrainedBox>(
        find.ancestor(of: find.text('Contenido Central'), matching: find.byType(ConstrainedBox)).first,
      );
      expect(constrainedBox.constraints.maxWidth, 900);

      final padding = tester.widget<Padding>(
        find.ancestor(of: find.text('Contenido Central'), matching: find.byType(Padding)).first,
      );
      expect(padding.padding, const EdgeInsets.all(24));
    });
  });
}
