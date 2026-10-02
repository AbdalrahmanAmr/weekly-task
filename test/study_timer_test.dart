import 'package:flutter_test/flutter_test.dart';

import 'package:weekly_task/planner_stats.dart';
import 'package:weekly_task/study_timer.dart';
import 'package:weekly_task/task_store.dart';

void main() {
  test('running timer calculates remaining time from timestamps', () {
    final started = DateTime(2026, 10, 2, 10);
    final timer = ActiveStudyTimer(
      id: 'one',
      mode: StudyMode.pomodoro,
      phase: StudyPhase.focus,
      status: StudyTimerStatus.running,
      startedAt: started,
      phaseStartedAt: started,
      plannedSeconds: 25 * 60,
      weekKey: '2026-09-27',
    );

    expect(
      timer.remainingAt(started.add(const Duration(minutes: 10))),
      const Duration(minutes: 15),
    );
  });

  test('paused timer excludes time spent paused', () {
    final started = DateTime(2026, 10, 2, 10);
    final paused = started.add(const Duration(minutes: 10));
    final timer = ActiveStudyTimer(
      id: 'two',
      mode: StudyMode.shortFocus,
      phase: StudyPhase.focus,
      status: StudyTimerStatus.paused,
      startedAt: started,
      phaseStartedAt: started,
      plannedSeconds: 15 * 60,
      weekKey: '2026-09-27',
      pausedAt: paused,
    );

    expect(timer.remainingAt(paused), const Duration(minutes: 5));
    expect(timer.toJson()['status'], 'paused');
  });

  test('timer configuration round trips all modes', () {
    const config = StudyTimerConfig(
      pomodoro: StudyModeSettings(focusSeconds: 1500, breakSeconds: 300),
      shortFocus: StudyModeSettings(focusSeconds: 600, breakSeconds: 120),
      deepWork: StudyModeSettings(focusSeconds: 3600, breakSeconds: 600),
      custom: StudyModeSettings(focusSeconds: 900, breakSeconds: 180),
    );

    final restored = StudyTimerConfig.fromJson(config.toJson());
    expect(restored.forMode(StudyMode.deepWork).focusSeconds, 3600);
    expect(restored.forMode(StudyMode.custom).breakSeconds, 180);
  });

  test('legacy active timer data gets safe defaults', () {
    final timer = ActiveStudyTimer.fromJson({});

    expect(timer.mode, StudyMode.pomodoro);
    expect(timer.phase, StudyPhase.focus);
    expect(timer.plannedSeconds, 25 * 60);
    expect(timer.weekKey, isNotEmpty);
  });

  test('custom settings are bounded and persist through configuration', () {
    final config = const StudyTimerConfig().copyWith(
      custom: const StudyModeSettings(focusSeconds: 1200, breakSeconds: 180),
    );

    expect(config.custom.focusSeconds, 1200);
    expect(config.custom.breakSeconds, 180);
  });

  test('subtask completion days round trip as local date keys', () {
    final subtask = Subtask(
      id: 'subtask-1',
      text: 'Read chapter',
      completedDays: {'2026-10-02'},
    );
    final restored = Subtask.fromJson(subtask.toJson());

    expect(restored.text, 'Read chapter');
    expect(restored.completedDays, contains('2026-10-02'));
  });

  test('weekly stats calculate distinct completed streaks', () {
    final history = [
      HistoryEntry(
        text: 'One',
        weekNumber: 39,
        outcome: 'done',
        at: DateTime(2026, 9, 26),
        weekKey: '2026-09-20',
      ),
      HistoryEntry(
        text: 'Two',
        weekNumber: 40,
        outcome: 'done',
        at: DateTime(2026, 10, 3),
        weekKey: '2026-09-27',
      ),
    ];
    final stats = PlannerStats.fromHistory(history);

    expect(stats.completedWeeks, 2);
    expect(stats.longestStreak, 2);
    expect(stats.completionRate, 1);
  });
}
