import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarketplaceService Static Query Privacy Guard', () {
    late String serviceCode;

    setUpAll(() {
      final possiblePaths = [
        'lib/core/services/marketplace_service.dart',
        'comunidad_universitaria/lib/core/services/marketplace_service.dart',
        '../comunidad_universitaria/lib/core/services/marketplace_service.dart',
      ];
      File? targetFile;
      for (final p in possiblePaths) {
        final f = File(p);
        if (f.existsSync()) {
          targetFile = f;
          break;
        }
      }
      expect(
        targetFile,
        isNotNull,
        reason: 'El archivo marketplace_service.dart debe existir en el repositorio',
      );
      serviceCode = targetFile!.readAsStringSync();
    });

    test('No contiene .select(...) con user_id sobre marketplace_items', () {
      // 1. Prohibido seleccionar user_id en la lista global de columnas públicas de marketplace (_marketColumns)
      final marketColumnsMatch = RegExp(r"_marketColumns\s*=\s*'([^']+)'").firstMatch(serviceCode);
      expect(marketColumnsMatch, isNotNull, reason: '_marketColumns debe estar definido');
      final marketCols = marketColumnsMatch!.group(1)!.split(',').map((s) => s.trim()).toList();
      expect(
        marketCols.contains('user_id'),
        isFalse,
        reason: '_marketColumns no debe incluir user_id para proteger el anonimato',
      );

      // 2. Prohibido seleccionar user_id en explicitColumns (usado tras inserts)
      final explicitColsMatch = RegExp(r"explicitColumns\s*=\s*'([^']+)'").firstMatch(serviceCode);
      expect(explicitColsMatch, isNotNull, reason: 'explicitColumns debe estar definido');
      final explicitCols = explicitColsMatch!.group(1)!.split(',').map((s) => s.trim()).toList();
      expect(
        explicitCols.contains('user_id'),
        isFalse,
        reason: 'explicitCols no debe incluir user_id',
      );

      // 3. Inspeccionar cualquier llamada .from('marketplace_items').select(...)
      final queryMatches = RegExp(r"\.from\(\s*[']marketplace_items[']\s*\)\s*\.select\(([^)]*)\)").allMatches(serviceCode);
      for (final match in queryMatches) {
        final selectArg = match.group(1)!.trim();
        expect(
          selectArg.contains('user_id'),
          isFalse,
          reason: 'Consulta sobre marketplace_items no debe proyectar user_id: $selectArg',
        );
      }
    });

    test('No contiene SELECT * ni .select(*) sobre marketplace_items', () {
      // Prohibir wildcard select sobre marketplace_items
      final wildcardSelect = RegExp(r"\.from\(\s*[']marketplace_items[']\s*\)\s*\.select\(\s*[']\*[']\s*\)");
      expect(
        wildcardSelect.hasMatch(serviceCode),
        isFalse,
        reason: 'No se debe hacer select(*) sobre marketplace_items',
      );

      final sqlWildcard = RegExp(r'SELECT\s+\*\s+FROM\s+marketplace_items', caseSensitive: false);
      expect(
        sqlWildcard.hasMatch(serviceCode),
        isFalse,
        reason: 'No se debe usar SELECT * FROM marketplace_items en texto SQL',
      );
    });
  });
}
