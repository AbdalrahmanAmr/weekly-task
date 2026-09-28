const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];

String _two(int n) => n.toString().padLeft(2, '0');

String formatLong(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}, ${d.year}';

String formatShort(DateTime d) =>
    '${_months[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';

/// ISO 8601 week number of [date].
int _isoWeek(DateTime date) {
  final d = DateTime.utc(date.year, date.month, date.day);
  final thursday = d.add(Duration(days: 4 - d.weekday));
  final firstJan = DateTime.utc(thursday.year, 1, 1);
  return (thursday.difference(firstJan).inDays / 7).floor() + 1;
}

/// A Sunday -> Saturday week. The number is the ISO week of the Monday
/// inside it, so Sun 27 Sep - Sat 3 Oct 2026 is week 40.
class WeekInfo {
  const WeekInfo._(this.start, this.end, this.number, this.daysLeft);

  final DateTime start; // Sunday 00:00 (local)
  final DateTime end; // Saturday 00:00 (local)
  final int number;
  final int daysLeft; // 0 on Saturday

  /// Stable id for the week, e.g. "2026-09-27" (its Sunday).
  String get key => '${start.year}-${_two(start.month)}-${_two(start.day)}';

  factory WeekInfo.of(DateTime now) {
    // Dart: Monday = 1 ... Sunday = 7, so weekday % 7 = days since Sunday.
    final start = DateTime(now.year, now.month, now.day - (now.weekday % 7));
    final end = DateTime(start.year, start.month, start.day + 6);
    final monday = DateTime(start.year, start.month, start.day + 1);
    final left = DateTime.utc(end.year, end.month, end.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;
    return WeekInfo._(start, end, _isoWeek(monday), left);
  }

  factory WeekInfo.now() => WeekInfo.of(DateTime.now());
}
