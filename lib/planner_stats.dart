import 'task_store.dart';
import 'week_utils.dart';

class PlannerStats {
  const PlannerStats({
    required this.completedWeeks,
    required this.recordedWeeks,
    required this.completionRate,
    required this.currentStreak,
    required this.longestStreak,
  });

  final int completedWeeks;
  final int recordedWeeks;
  final double completionRate;
  final int currentStreak;
  final int longestStreak;

  factory PlannerStats.fromHistory(List<HistoryEntry> history) {
    final byWeek = <String, HistoryEntry>{};
    for (final entry in history) {
      final key = entry.weekKey;
      if (key != null) byWeek[key] = entry;
    }
    final completed = byWeek.values.where((e) => e.outcome == 'done').toList();
    final ordered = byWeek.keys.map(DateTime.parse).toList()..sort();
    var longest = 0;
    var run = 0;
    DateTime? previous;
    for (final week in ordered) {
      final entry = byWeek[dateKey(week)];
      if (entry?.outcome == 'done' &&
          (previous == null || week.difference(previous).inDays == 7)) {
        run++;
      } else if (entry?.outcome == 'done') {
        run = 1;
      } else {
        run = 0;
      }
      if (run > longest) longest = run;
      previous = week;
    }

    var current = 0;
    final thisWeek = WeekInfo.now().start;
    var cursor = thisWeek;
    while (byWeek[dateKey(cursor)]?.outcome == 'done') {
      current++;
      cursor = cursor.subtract(const Duration(days: 7));
    }

    return PlannerStats(
      completedWeeks: completed.length,
      recordedWeeks: byWeek.length,
      completionRate:
          byWeek.isEmpty ? 0 : completed.length / byWeek.length,
      currentStreak: current,
      longestStreak: longest,
    );
  }
}
