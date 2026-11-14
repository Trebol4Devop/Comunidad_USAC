/// Helper to calculate store open/closed status according to Guatemala time (America/Guatemala, UTC-6).
class BusinessHoursHelper {
  static const List<String> _dayKeys = [
    'mon', // 1: Monday
    'tue', // 2: Tuesday
    'wed', // 3: Wednesday
    'thu', // 4: Thursday
    'fri', // 5: Friday
    'sat', // 6: Saturday
    'sun', // 7: Sunday
  ];

  static const Map<String, String> dayNamesSpanish = {
    'mon': 'Lunes',
    'tue': 'Martes',
    'wed': 'Miércoles',
    'thu': 'Jueves',
    'fri': 'Viernes',
    'sat': 'Sábado',
    'sun': 'Domingo',
  };

  /// Calculates whether the store is currently open according to Guatemala time (UTC-6).
  /// Returns `null` if [businessHours] is null, empty or does not contain schedule for today.
  static bool? isOpenNow(Map<String, dynamic>? businessHours) {
    if (businessHours == null || businessHours.isEmpty) return null;

    final nowUtc = DateTime.now().toUtc();
    final guatemalaNow = nowUtc.subtract(const Duration(hours: 6));
    final weekday = guatemalaNow.weekday; // 1 = Monday .. 7 = Sunday
    final dayKey = _dayKeys[weekday - 1];

    final dayData = businessHours[dayKey];
    if (dayData is! Map) return null;

    final isClosed = dayData['closed'] == true;
    if (isClosed) return false;

    final openStr = dayData['open']?.toString();
    final closeStr = dayData['close']?.toString();
    if (openStr == null || closeStr == null) return null;

    final openParts = openStr.split(':');
    final closeParts = closeStr.split(':');
    if (openParts.length < 2 || closeParts.length < 2) return null;

    final openHour = int.tryParse(openParts[0]);
    final openMinute = int.tryParse(openParts[1]);
    final closeHour = int.tryParse(closeParts[0]);
    final closeMinute = int.tryParse(closeParts[1]);
    if (openHour == null ||
        openMinute == null ||
        closeHour == null ||
        closeMinute == null) {
      return null;
    }

    final currentMinutes = guatemalaNow.hour * 60 + guatemalaNow.minute;
    final openMinutes = openHour * 60 + openMinute;
    final closeMinutes = closeHour * 60 + closeMinute;

    return currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
  }

  /// Returns a human-friendly status string: "Abierto ahora", "Cerrado", or "Horario no disponible".
  static String formatStatus(Map<String, dynamic>? businessHours) {
    final status = isOpenNow(businessHours);
    if (status == null) return 'Horario no disponible';
    return status ? 'Abierto ahora' : 'Cerrado';
  }
}
