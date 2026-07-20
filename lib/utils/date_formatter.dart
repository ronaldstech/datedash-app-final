import '../providers/language_provider.dart';

class DateFormatter {
  static String format(DateTime dateTime, LanguageProvider lp) {
    final DateTime now = DateTime.now();
    final Duration diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return lp.getString('just_now');
    } else if (diff.inMinutes < 60) {
      return lp.getString('min_ago').replaceAll('{n}', diff.inMinutes.toString());
    } else if (diff.inHours < 24) {
      return lp.getString('hr_ago').replaceAll('{n}', diff.inHours.toString());
    } else if (diff.inDays == 1 || (now.day != dateTime.day && diff.inHours < 48)) {
      return lp.getString('yesterday');
    } else if (diff.inDays < 7) {
      return lp.getString('days_ago').replaceAll('{n}', diff.inDays.toString());
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final yearStr = dateTime.year == now.year ? '' : ', ${dateTime.year}';
      return '${months[dateTime.month - 1]} ${dateTime.day}$yearStr';
    }
  }

  static String formatDateDivider(DateTime dateTime, LanguageProvider lp) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final DateTime msgDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (msgDate == today) {
      return lp.getString('today');
    } else if (msgDate == yesterday) {
      return lp.getString('yesterday');
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final yearStr = dateTime.year == now.year ? '' : ' ${dateTime.year}';
      return '${dateTime.day} ${months[dateTime.month - 1]}$yearStr';
    }
  }

  static String formatClockTime(DateTime dateTime) {
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  static String formatMeetupDateTime(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at $hour:$minute';
  }
}
