class TimeUtils {
  static const List<String> _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
  ];

  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Hace un momento';
    } else if (difference.inMinutes < 60) {
      final m = difference.inMinutes;
      return 'Hace $m ${m == 1 ? 'minuto' : 'minutos'}';
    } else if (difference.inHours < 24) {
      final h = difference.inHours;
      return 'Hace $h ${h == 1 ? 'hora' : 'horas'}';
    } else if (difference.inDays == 1) {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final min = dateTime.minute.toString().padLeft(2, '0');
      return 'Ayer a las $hour:$min';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else if (dateTime.year == now.year) {
      final month = _months[dateTime.month - 1];
      return '${dateTime.day} $month';
    } else {
      final month = _months[dateTime.month - 1];
      return '${dateTime.day} $month ${dateTime.year}';
    }
  }
}
