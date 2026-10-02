import 'dart:math' as math;

import 'week_utils.dart';

enum StudyMode { pomodoro, shortFocus, deepWork, custom }

enum StudyPhase { focus, shortBreak, longBreak }

enum StudyTimerStatus { running, paused, waitingForBreak, waitingForFocus }

class StudyModeSettings {
  const StudyModeSettings({
    required this.focusSeconds,
    required this.breakSeconds,
    this.longBreakSeconds = 15 * 60,
  });

  final int focusSeconds;
  final int breakSeconds;
  final int longBreakSeconds;

  Map<String, dynamic> toJson() => {
        'focusSeconds': focusSeconds,
        'breakSeconds': breakSeconds,
        'longBreakSeconds': longBreakSeconds,
      };

  factory StudyModeSettings.fromJson(Map<String, dynamic> json) {
    return StudyModeSettings(
      focusSeconds: _boundedInt(json['focusSeconds'], 60, 4 * 60 * 60, 25 * 60),
      breakSeconds: _boundedInt(json['breakSeconds'], 0, 60 * 60, 5 * 60),
      longBreakSeconds:
          _boundedInt(json['longBreakSeconds'], 0, 2 * 60 * 60, 15 * 60),
    );
  }
}

class StudyTimerConfig {
  const StudyTimerConfig({
    this.pomodoro = const StudyModeSettings(
      focusSeconds: 25 * 60,
      breakSeconds: 5 * 60,
    ),
    this.shortFocus = const StudyModeSettings(
      focusSeconds: 15 * 60,
      breakSeconds: 5 * 60,
    ),
    this.deepWork = const StudyModeSettings(
      focusSeconds: 50 * 60,
      breakSeconds: 10 * 60,
    ),
    this.custom = const StudyModeSettings(
      focusSeconds: 30 * 60,
      breakSeconds: 5 * 60,
    ),
  });

  final StudyModeSettings pomodoro;
  final StudyModeSettings shortFocus;
  final StudyModeSettings deepWork;
  final StudyModeSettings custom;

  StudyModeSettings forMode(StudyMode mode) {
    switch (mode) {
      case StudyMode.pomodoro:
        return pomodoro;
      case StudyMode.shortFocus:
        return shortFocus;
      case StudyMode.deepWork:
        return deepWork;
      case StudyMode.custom:
        return custom;
    }
  }

  Map<String, dynamic> toJson() => {
        'pomodoro': pomodoro.toJson(),
        'shortFocus': shortFocus.toJson(),
        'deepWork': deepWork.toJson(),
        'custom': custom.toJson(),
      };

  factory StudyTimerConfig.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> settings(String key, StudyModeSettings fallback) {
      final value = json[key];
      return value is Map<String, dynamic> ? value : fallback.toJson();
    }

    const defaults = StudyTimerConfig();
    return StudyTimerConfig(
      pomodoro: StudyModeSettings.fromJson(settings('pomodoro', defaults.pomodoro)),
      shortFocus:
          StudyModeSettings.fromJson(settings('shortFocus', defaults.shortFocus)),
      deepWork: StudyModeSettings.fromJson(settings('deepWork', defaults.deepWork)),
      custom: StudyModeSettings.fromJson(settings('custom', defaults.custom)),
    );
  }
}

class ActiveStudyTimer {
  ActiveStudyTimer({
    required this.id,
    required this.mode,
    required this.phase,
    required this.status,
    required this.startedAt,
    required this.phaseStartedAt,
    required this.plannedSeconds,
    required this.weekKey,
    this.taskText,
    this.completedFocusCount = 0,
    this.pausedAt,
    this.pausedSeconds = 0,
  });

  final String id;
  final StudyMode mode;
  final StudyPhase phase;
  final StudyTimerStatus status;
  final DateTime startedAt;
  final DateTime phaseStartedAt;
  final int plannedSeconds;
  final String weekKey;
  final String? taskText;
  final int completedFocusCount;
  final DateTime? pausedAt;
  final int pausedSeconds;

  bool get isFocus => phase == StudyPhase.focus;

  Duration remainingAt(DateTime now) {
    if (status == StudyTimerStatus.paused && pausedAt != null) {
      return _remainingFromElapsed(pausedAt!, pausedSeconds);
    }
    if (status != StudyTimerStatus.running) {
      return Duration(seconds: plannedSeconds);
    }
    return _remainingFromElapsed(now, pausedSeconds);
  }

  bool isExpiredAt(DateTime now) => remainingAt(now) <= Duration.zero;

  Duration _remainingFromElapsed(DateTime now, int extraPausedSeconds) {
    final elapsed = now.difference(phaseStartedAt).inSeconds - extraPausedSeconds;
    return Duration(seconds: math.max(0, plannedSeconds - elapsed));
  }

  ActiveStudyTimer copyWith({
    StudyPhase? phase,
    StudyTimerStatus? status,
    DateTime? phaseStartedAt,
    int? plannedSeconds,
    int? completedFocusCount,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    int? pausedSeconds,
  }) {
    return ActiveStudyTimer(
      id: id,
      mode: mode,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      startedAt: startedAt,
      phaseStartedAt: phaseStartedAt ?? this.phaseStartedAt,
      plannedSeconds: plannedSeconds ?? this.plannedSeconds,
      weekKey: weekKey,
      taskText: taskText,
      completedFocusCount: completedFocusCount ?? this.completedFocusCount,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.name,
        'phase': phase.name,
        'status': status.name,
        'startedAt': startedAt.toIso8601String(),
        'phaseStartedAt': phaseStartedAt.toIso8601String(),
        'plannedSeconds': plannedSeconds,
        'weekKey': weekKey,
        'taskText': taskText,
        'completedFocusCount': completedFocusCount,
        'pausedAt': pausedAt?.toIso8601String(),
        'pausedSeconds': pausedSeconds,
      };

  factory ActiveStudyTimer.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ActiveStudyTimer(
      id: json['id'] as String? ?? now.microsecondsSinceEpoch.toString(),
      mode: _enumByName(StudyMode.values, json['mode'], StudyMode.pomodoro),
      phase: _enumByName(StudyPhase.values, json['phase'], StudyPhase.focus),
      status: _enumByName(
          StudyTimerStatus.values, json['status'], StudyTimerStatus.running),
      startedAt: _date(json['startedAt']) ?? now,
      phaseStartedAt: _date(json['phaseStartedAt']) ?? now,
      plannedSeconds: _boundedInt(
          json['plannedSeconds'], 1, 4 * 60 * 60, 25 * 60),
      weekKey: json['weekKey'] as String? ?? WeekInfo.now().key,
      taskText: json['taskText'] as String?,
      completedFocusCount: math.max(0, json['completedFocusCount'] as int? ?? 0),
      pausedAt: _date(json['pausedAt']),
      pausedSeconds: math.max(0, json['pausedSeconds'] as int? ?? 0),
    );
  }
}

class StudySession {
  StudySession({
    required this.id,
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.actualSeconds,
    required this.completed,
    required this.weekKey,
    this.taskText,
  });

  final String id;
  final StudyMode mode;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedSeconds;
  final int actualSeconds;
  final bool completed;
  final String weekKey;
  final String? taskText;

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.name,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'plannedSeconds': plannedSeconds,
        'actualSeconds': actualSeconds,
        'completed': completed,
        'weekKey': weekKey,
        'taskText': taskText,
      };

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return StudySession(
      id: json['id'] as String? ?? now.microsecondsSinceEpoch.toString(),
      mode: _enumByName(StudyMode.values, json['mode'], StudyMode.pomodoro),
      startedAt: _date(json['startedAt']) ?? now,
      endedAt: _date(json['endedAt']) ?? now,
      plannedSeconds:
          _boundedInt(json['plannedSeconds'], 1, 4 * 60 * 60, 25 * 60),
      actualSeconds: _boundedInt(json['actualSeconds'], 0, 4 * 60 * 60, 0),
      completed: json['completed'] as bool? ?? false,
      weekKey: json['weekKey'] as String? ?? WeekInfo.now().key,
      taskText: json['taskText'] as String?,
    );
  }
}

int _boundedInt(Object? value, int min, int max, int fallback) {
  final number = value is int ? value : fallback;
  return number.clamp(min, max);
}

T _enumByName<T extends Enum>(List<T> values, Object? value, T fallback) {
  for (final item in values) {
    if (item.name == value) return item;
  }
  return fallback;
}

DateTime? _date(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
