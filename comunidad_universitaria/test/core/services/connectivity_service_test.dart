import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:comunidad_universitaria/core/services/connectivity_service.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityService Helper Methods', () {
    test('isOnline evalúa correctamente interfaces activas', () {
      expect(ConnectivityService.isOnline([ConnectivityResult.wifi]), isTrue);
      expect(ConnectivityService.isOnline([ConnectivityResult.mobile]), isTrue);
      expect(ConnectivityService.isOnline([ConnectivityResult.ethernet]), isTrue);
      expect(ConnectivityService.isOnline([ConnectivityResult.vpn]), isTrue);
      expect(ConnectivityService.isOnline([ConnectivityResult.other]), isTrue);
      expect(ConnectivityService.isOnline([ConnectivityResult.none]), isFalse);
      expect(ConnectivityService.isOnline([]), isFalse);
      expect(
        ConnectivityService.isOnline([ConnectivityResult.none, ConnectivityResult.wifi]),
        isTrue,
      );
    });

    test('getConnectionTypeDescription retorna descripciones en español según UX', () {
      expect(
        ConnectivityService.getConnectionTypeDescription([ConnectivityResult.wifi]),
        equals('Wi-Fi'),
      );
      expect(
        ConnectivityService.getConnectionTypeDescription([ConnectivityResult.mobile]),
        equals('Datos móviles'),
      );
      expect(
        ConnectivityService.getConnectionTypeDescription([ConnectivityResult.ethernet]),
        equals('Ethernet'),
      );
      expect(
        ConnectivityService.getConnectionTypeDescription([ConnectivityResult.vpn]),
        equals('VPN'),
      );
      expect(
        ConnectivityService.getConnectionTypeDescription([ConnectivityResult.none]),
        equals('Sin conexión'),
      );
      expect(
        ConnectivityService.getConnectionTypeDescription([]),
        equals('Sin conexión'),
      );
    });
  });

  group('ConnectivityService Instance & Mocks', () {
    tearDown(() {
      ConnectivityService.debugIsConnected = null;
    });

    test('debugIsConnected tiene prioridad sobre llamadas nativas en tests', () async {
      final service = ConnectivityService.instance;

      ConnectivityService.debugIsConnected = true;
      expect(await service.isConnected, isTrue);

      ConnectivityService.debugIsConnected = false;
      expect(await service.isConnected, isFalse);
    });

    test('Constructor custom inyecta Connectivity mockeado y consulta checkConnectivity', () async {
      final mock = MockConnectivity();
      when(() => mock.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);

      final service = ConnectivityService.custom(connectivity: mock);
      final isConnected = await service.isConnected;
      final rawResults = await service.checkConnectivity();

      expect(isConnected, isTrue);
      expect(rawResults, equals([ConnectivityResult.wifi]));
      verify(() => mock.checkConnectivity()).called(2);
    });

    test('onConnectivityChanged mapea stream de interfaces a booleanos distintos', () async {
      final mock = MockConnectivity();
      final controller = StreamController<List<ConnectivityResult>>();

      when(() => mock.onConnectivityChanged).thenAnswer((_) => controller.stream);

      final service = ConnectivityService.custom(connectivity: mock);
      final events = <bool>[];
      final sub = service.onConnectivityChanged.listen(events.add);

      controller.add([ConnectivityResult.wifi]);
      controller.add([ConnectivityResult.mobile]); // Ambos online, distinct() debe omitir duplicado consecutivo
      controller.add([ConnectivityResult.none]);   // offline
      controller.add([ConnectivityResult.ethernet]); // online de nuevo

      await pumpEventQueue();

      expect(events, equals([true, false, true]));
      await sub.cancel();
      await controller.close();
    });
  });
}
