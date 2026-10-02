import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifier.dart';
import 'study_timer.dart';
import 'week_utils.dart';

class Task {
  Task({
    required this.text,
    required this.weekKey,
    required this.weekNumber,
    this.done = false,
  });

  String text;
  String weekKey;
  int weekNumber;
  bool done;

  Map<String, dynamic> toJson() => {
        'text': text,
        'weekKey': weekKey,
        'weekNumber': weekNumber,
        'done': done,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        text: j['text'] as String,
        weekKey: j['weekKey'] as String,
        weekNumber: j['weekNumber'] as int,
        done: (j['done'] as bool?) ?? false,
      );
}

/// outcome is one of: 'done', 'replaced', 'dropped'
class HistoryEntry {
  HistoryEntry({
    required this.text,
    required this.weekNumber,
    required this.outcome,
    required this.at,
  });

  final String text;
  final int weekNumber;
  final String outcome;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'text': text,
        'weekNumber': weekNumber,
        'outcome': outcome,
        'at': at.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        text: j['text'] as String,
        weekNumber: j['weekNumber'] as int,
        outcome: j['outcome'] as String,
        at: DateTime.parse(j['at'] as String),
      );
}

class TaskStore extends ChangeNotifier {
  static const _key = 'weekly_task_state_v1';

  Task? current;
  String? next;
  String? lastSeenWeek;
  final List<HistoryEntry> history = [];
  ActiveStudyTimer? activeStudyTimer;
  final List<StudySession> studySessions = [];
  StudyTimerConfig studyTimerConfig = const StudyTimerConfig();
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        current = j['current'] == null
            ? null
            : Task.fromJson(j['current'] as Map<String, dynamic>);
        next = j['next'] as String?;
        lastSeenWeek = j['lastSeenWeek'] as String?;
        history
          ..clear()
          ..addAll((j['history'] as List? ?? [])
              .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>)));
        final active = j['activeStudyTimer'];
        activeStudyTimer = active is Map<String, dynamic>
            ? ActiveStudyTimer.fromJson(active)
            : null;
        studySessions
          ..clear()
          ..addAll((j['studySessions'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(StudySession.fromJson));
        final config = j['studySettings'];
        if (config is Map<String, dynamic>) {
          studyTimerConfig = StudyTimerConfig.fromJson(config);
        }
      } catch (_) {
        // corrupted data: start fresh
      }
    }
    await refresh(notify: false);
    await _syncWeekEndAlert();
  }

  Future<void> _save() async {
    final data = {
      'current': current?.toJson(),
      'next': next,
      'lastSeenWeek': lastSeenWeek,
      'history': history.map((e) => e.toJson()).toList(),
      'activeStudyTimer': activeStudyTimer?.toJson(),
      'studySessions': studySessions.take(500).map((e) => e.toJson()).toList(),
      'studySettings': studyTimerConfig.toJson(),
    };
    await _prefs?.setString(_key, jsonEncode(data));
    await _syncWeekEndAlert();
    await _syncStudyTimerAlert();
  }

  Future<void> _syncStudyTimerAlert() async {
    final active = activeStudyTimer;
    if (active == null || active.status != StudyTimerStatus.running) {
      await AppNotifier.cancelStudyTimer();
      return;
    }
    final when = active.phaseStartedAt.add(
      Duration(seconds: active.plannedSeconds + active.pausedSeconds),
    );
    final label = active.phase == StudyPhase.focus ? 'Focus' : 'Break';
    await AppNotifier.scheduleStudyTimer(
      when: when,
      title: '$label phase complete',
      body: active.phase == StudyPhase.focus
          ? 'Your focus session is complete.'
          : 'Your break is complete.',
    );
  }

  /// Handles week rollover: promotes the queued task if the last one was
  /// finished, and (when [notify] is true) shows a Windows notification.
  Future<void> refresh({bool notify = true}) async {
    final w = WeekInfo.now();
    var changed = false;
    String? title;
    String? body;

    final weekChanged = lastSeenWeek != null && lastSeenWeek != w.key;

    final c = current;
    if (c != null && c.weekKey != w.key && c.done) {
      if (next != null) {
        current = Task(text: next!, weekKey: w.key, weekNumber: w.number);
        next = null;
      } else {
        current = null;
      }
      changed = true;
    }

    if (weekChanged && notify) {
      final cur = current;
      if (cur == null) {
        title = 'Week ${w.number} started';
        body = 'No task yet. Open Weekly Task and set one.';
      } else if (cur.weekKey != w.key) {
        title = 'Week ended - task not finished';
        body = '"${cur.text}": keep it, replace it, or drop it?';
      } else {
        title = 'Week ${w.number} started';
        body = 'This week: ${cur.text}';
      }
    }

    if (lastSeenWeek != w.key) {
      lastSeenWeek = w.key;
      changed = true;
    }

    if (changed) {
      await _save();
      notifyListeners();
    }
    await reconcileStudyTimer(notify: false);
    if (title != null && body != null) {
      await AppNotifier.show(title, body);
    }
  }

  /// Android: schedules one notification for Sunday 09:00 (start of next
  /// week). Its text depends on the current state, so this runs after every
  /// save and the pending notification always matches what the app would do.
  Future<void> _syncWeekEndAlert() async {
    final w = WeekInfo.now();
    final when = DateTime(w.end.year, w.end.month, w.end.day + 1, 9);
    final upcoming = WeekInfo.of(when).number;
    final c = current;

    String title;
    String body;
    if (c == null) {
      title = 'Week $upcoming started';
      body = 'No task yet. Open Weekly Task and set one.';
    } else if (c.done) {
      if (next != null) {
        title = 'Week $upcoming started';
        body = 'This week: $next';
      } else {
        title = 'Week ${w.number} finished';
        body = 'Nice work. Set your task for week $upcoming.';
      }
    } else {
      title = 'Week ended - task not finished';
      body = '"${c.text}": keep it, replace it, or drop it?';
    }
    await AppNotifier.scheduleWeekEnd(when: when, title: title, body: body);
  }

  void _log(Task t, String outcome) {
    history.add(HistoryEntry(
      text: t.text,
      weekNumber: t.weekNumber,
      outcome: outcome,
      at: DateTime.now(),
    ));
  }

  Future<void> _commit() async {
    await _save();
    notifyListeners();
  }

  Future<void> setTask(String text) async {
    final w = WeekInfo.now();
    current = Task(text: text, weekKey: w.key, weekNumber: w.number);
    await _commit();
  }

  Future<void> complete() async {
    final c = current;
    if (c == null || c.done) return;
    c.done = true;
    _log(c, 'done');
    await _commit();
  }

  Future<void> keepTask() async {
    final c = current;
    if (c == null) return;
    final w = WeekInfo.now();
    c.weekKey = w.key;
    c.weekNumber = w.number;
    await _commit();
  }

  Future<void> replaceTask(String text) async {
    final c = current;
    if (c != null) _log(c, 'replaced');
    await setTask(text);
  }

  Future<void> dropTask() async {
    final c = current;
    if (c != null) _log(c, 'dropped');
    current = null;
    await _commit();
  }

  Future<void> setNext(String text) async {
    next = text;
    await _commit();
  }

  Future<void> clearNext() async {
    next = null;
    await _commit();
  }

  Future<void> startStudySession(StudyMode mode) async {
    if (activeStudyTimer != null) return;
    final now = DateTime.now();
    final settings = studyTimerConfig.forMode(mode);
    activeStudyTimer = ActiveStudyTimer(
      id: '${now.microsecondsSinceEpoch}',
      mode: mode,
      phase: StudyPhase.focus,
      status: StudyTimerStatus.running,
      startedAt: now,
      phaseStartedAt: now,
      plannedSeconds: settings.focusSeconds,
      weekKey: WeekInfo.now().key,
      taskText: current?.text,
    );
    await _commit();
  }

  Future<void> pauseStudySession() async {
    final active = activeStudyTimer;
    if (active == null || active.status != StudyTimerStatus.running) return;
    activeStudyTimer = active.copyWith(
      status: StudyTimerStatus.paused,
      pausedAt: DateTime.now(),
    );
    await _commit();
  }

  Future<void> resumeStudySession() async {
    final active = activeStudyTimer;
    if (active == null || active.status != StudyTimerStatus.paused) return;
    final now = DateTime.now();
    final pausedAt = active.pausedAt ?? now;
    activeStudyTimer = active.copyWith(
      status: StudyTimerStatus.running,
      pausedSeconds: active.pausedSeconds + now.difference(pausedAt).inSeconds,
      clearPausedAt: true,
    );
    await _commit();
  }

  Future<void> resetStudySession() async {
    if (activeStudyTimer == null) return;
    activeStudyTimer = null;
    await _commit();
  }

  Future<void> skipStudyBreak() async {
    final active = activeStudyTimer;
    if (active == null ||
        (active.status != StudyTimerStatus.waitingForBreak &&
            active.status != StudyTimerStatus.waitingForFocus)) {
      return;
    }
    activeStudyTimer = active.status == StudyTimerStatus.waitingForFocus
        ? null
        : _nextFocus(active);
    await _commit();
  }

  Future<void> startStudyBreak() async {
    final active = activeStudyTimer;
    if (active == null || active.status != StudyTimerStatus.waitingForBreak) {
      return;
    }
    final settings = studyTimerConfig.forMode(active.mode);
    final longBreak = active.completedFocusCount % 4 == 0;
    activeStudyTimer = active.copyWith(
      phase: longBreak ? StudyPhase.longBreak : StudyPhase.shortBreak,
      status: StudyTimerStatus.running,
      phaseStartedAt: DateTime.now(),
      plannedSeconds:
          longBreak ? settings.longBreakSeconds : settings.breakSeconds,
      clearPausedAt: true,
      pausedSeconds: 0,
    );
    await _commit();
  }

  Future<void> reconcileStudyTimer({bool notify = true}) async {
    final active = activeStudyTimer;
    if (active == null ||
        active.status != StudyTimerStatus.running ||
        !active.isExpiredAt(DateTime.now())) {
      return;
    }
    if (active.isFocus) {
      final now = DateTime.now();
      final actual = now.difference(active.phaseStartedAt).inSeconds;
      studySessions.removeWhere((session) => session.id == active.id);
      studySessions.insert(
        0,
        StudySession(
          id: active.id,
          mode: active.mode,
          startedAt: active.startedAt,
          endedAt: now,
          plannedSeconds: active.plannedSeconds,
          actualSeconds: actual.clamp(0, active.plannedSeconds),
          completed: true,
          weekKey: active.weekKey,
          taskText: active.taskText,
        ),
      );
      activeStudyTimer = active.copyWith(
        status: StudyTimerStatus.waitingForBreak,
        completedFocusCount: active.completedFocusCount + 1,
        clearPausedAt: true,
        pausedSeconds: 0,
      );
    } else {
      activeStudyTimer = _nextFocus(active);
    }
    await AppNotifier.show(
      '${active.phase == StudyPhase.focus ? 'Focus' : 'Break'} phase complete',
      active.phase == StudyPhase.focus
          ? 'Your focus session is complete.'
          : 'Your break is complete.',
    );
    await _save();
    if (notify) notifyListeners();
  }

  ActiveStudyTimer _nextFocus(ActiveStudyTimer active) {
    final now = DateTime.now();
    return active.copyWith(
      phase: StudyPhase.focus,
      status: StudyTimerStatus.running,
      phaseStartedAt: now,
      plannedSeconds: studyTimerConfig.forMode(active.mode).focusSeconds,
      clearPausedAt: true,
      pausedSeconds: 0,
    );
  }
}
