import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/utils/time_utils.dart';

void main() {
  group('TimeUtils.timeAgo', () {
    test('menos de 60 segundos devuelve "Hace un momento"', () {
      final now = DateTime.now();
      final dt = now.subtract(const Duration(seconds: 20));
      expect(TimeUtils.timeAgo(dt), 'Hace un momento');
    });

    test('entre 1 y 59 minutos devuelve "Hace 1 minuto" o "Hace N minutos"', () {
      final now = DateTime.now();

      final dt1Min = now.subtract(const Duration(minutes: 1, seconds: 5));
      expect(TimeUtils.timeAgo(dt1Min), 'Hace 1 minuto');

      final dt25Min = now.subtract(const Duration(minutes: 25));
      expect(TimeUtils.timeAgo(dt25Min), 'Hace 25 minutos');
    });

    test('entre 1 y 23 horas devuelve "Hace 1 hora" o "Hace N horas"', () {
      final now = DateTime.now();

      final dt1Hour = now.subtract(const Duration(hours: 1, minutes: 5));
      expect(TimeUtils.timeAgo(dt1Hour), 'Hace 1 hora');

      final dt6Hours = now.subtract(const Duration(hours: 6));
      expect(TimeUtils.timeAgo(dt6Hours), 'Hace 6 horas');
    });

    test('exactamente 1 día de diferencia devuelve "Ayer a las HH:mm"', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final hourStr = yesterday.hour.toString().padLeft(2, '0');
      final minStr = yesterday.minute.toString().padLeft(2, '0');

      expect(TimeUtils.timeAgo(yesterday), 'Ayer a las $hourStr:$minStr');
    });

    test('entre 2 y 6 días devuelve "Hace N días"', () {
      final now = DateTime.now();
      final dt3Days = now.subtract(const Duration(days: 3));
      expect(TimeUtils.timeAgo(dt3Days), 'Hace 3 días');

      final dt5Days = now.subtract(const Duration(days: 5));
      expect(TimeUtils.timeAgo(dt5Days), 'Hace 5 días');
    });

    test('más de 7 días pero en el mismo año devuelve "día mes"', () {
      final now = DateTime.now();
      // Aseguramos una fecha en el mismo año al menos 20 días atrás
      // Si estamos a inicio de año, proyectamos una fecha fija del año actual
      DateTime sameYearDate;
      if (now.month > 2) {
        sameYearDate = DateTime(now.year, now.month - 1, 10, 12, 0);
      } else {
        // En enero o febrero, si now.day > 10 restamos 8 días, si no testeamos con el mes 1 si dif > 7 días
        sameYearDate = now.subtract(const Duration(days: 15));
      }

      // Si la diferencia fuera menor a 7 días (improbable con 15 días o mes anterior), revisamos:
      if (now.difference(sameYearDate).inDays >= 7 && sameYearDate.year == now.year) {
        final result = TimeUtils.timeAgo(sameYearDate);
        expect(result, isNot(contains(now.year.toString())));
        expect(result, matches(RegExp(r'^\d{1,2}\s+[a-z]{3}$')));
      }
    });

    test('año anterior devuelve "día mes año"', () {
      final now = DateTime.now();
      final prevYearDate = DateTime(now.year - 1, 5, 20, 14, 30);
      final result = TimeUtils.timeAgo(prevYearDate);

      expect(result, contains((now.year - 1).toString()));
      expect(result, contains('may'));
      expect(result, contains('20'));
    });
  });
}
