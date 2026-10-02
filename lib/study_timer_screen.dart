import 'dart:async';

import 'package:flutter/material.dart';

import 'study_timer.dart';
import 'task_store.dart';

class StudyTimerScreen extends StatefulWidget {
  const StudyTimerScreen({super.key, required this.store});

  final TaskStore store;

  @override
  State<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends State<StudyTimerScreen> {
  Timer? _ticker;
  StudyMode _mode = StudyMode.pomodoro;

  TaskStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      await store.reconcileStudyTimer();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _modeLabel(StudyMode mode) {
    switch (mode) {
      case StudyMode.pomodoro:
        return 'Pomodoro';
      case StudyMode.shortFocus:
        return 'Short Focus';
      case StudyMode.deepWork:
        return 'Deep Work';
      case StudyMode.custom:
        return 'Custom';
    }
  }

  String _phaseLabel(StudyPhase phase) {
    switch (phase) {
      case StudyPhase.focus:
        return 'Focus';
      case StudyPhase.shortBreak:
        return 'Short break';
      case StudyPhase.longBreak:
        return 'Long break';
    }
  }

  String _time(Duration duration) {
    final seconds = duration.inSeconds;
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  Future<void> _start() async {
    await store.startStudySession(_mode);
  }

  Future<void> _reset() async {
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset timer?'),
        content: const Text('The current study session will be abandoned.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (shouldReset == true) await store.resetStudySession();
  }

  Widget _modePicker() {
    return DropdownButtonFormField<StudyMode>(
      initialValue: _mode,
      decoration: const InputDecoration(labelText: 'Session mode'),
      items: StudyMode.values
          .map((mode) => DropdownMenuItem(
                value: mode,
                child: Text(_modeLabel(mode)),
              ))
          .toList(),
      onChanged: store.activeStudyTimer == null
          ? (value) => setState(() => _mode = value ?? _mode)
          : null,
    );
  }

  Widget _waiting(BuildContext context, ActiveStudyTimer active) {
    final isBreak = active.status == StudyTimerStatus.waitingForBreak;
    return Column(
      children: [
        Text(
          isBreak ? 'Focus session complete' : 'Break complete',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          isBreak
              ? 'Start a break or skip it and continue focusing.'
              : 'Ready for another focus session?',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (isBreak)
          FilledButton.icon(
            onPressed: store.startStudyBreak,
            icon: const Icon(Icons.coffee),
            label: const Text('Start break'),
          ),
        OutlinedButton(
          onPressed: store.skipStudyBreak,
          child: Text(isBreak ? 'Skip break' : 'Finish'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study timer')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final active = store.activeStudyTimer;
              if (active == null) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Focus time',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('Start a session with or without a weekly task.'),
                    const SizedBox(height: 24),
                    _modePicker(),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start session'),
                    ),
                  ],
                );
              }
              if (active.status == StudyTimerStatus.waitingForBreak ||
                  active.status == StudyTimerStatus.waitingForFocus) {
                return Center(child: _waiting(context, active));
              }
              final remaining = active.remainingAt(DateTime.now());
              final paused = active.status == StudyTimerStatus.paused;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(_modeLabel(active.mode),
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(_phaseLabel(active.phase)),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      _time(remaining),
                      style: Theme.of(context)
                          .textTheme
                          .displayLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: paused
                        ? store.resumeStudySession
                        : store.pauseStudySession,
                    icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                    label: Text(paused ? 'Resume' : 'Pause'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.stop),
                    label: const Text('Reset'),
                  ),
                  if (active.taskText != null) ...[
                    const SizedBox(height: 24),
                    Text('Weekly task',
                        style: Theme.of(context).textTheme.labelLarge),
                    Text(active.taskText!),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
