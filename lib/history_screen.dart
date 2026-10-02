import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'planner_stats.dart';
import 'study_timer.dart';
import 'task_store.dart';
import 'week_utils.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            IconButton(
              tooltip: 'Calendar',
              icon: const Icon(Icons.calendar_month),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CalendarScreen(store: store),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Weeks'),
              Tab(text: 'Sessions'),
              Tab(text: 'Stats'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) => const TabBarView(
            children: [_WeeklyHistory(), _SessionHistory(), _TimerStats()],
          ),
        ),
      ),
    );
  }
}

class _WeeklyHistory extends StatelessWidget {
  const _WeeklyHistory();

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorWidgetOfExactType<HistoryScreen>();
    final store = screen!.store;
    final items = store.history.reversed.toList();
    if (items.isEmpty) return const Center(child: Text('No history yet.'));
    final doneCount = items.where((e) => e.outcome == 'done').length;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView.separated(
          itemCount: items.length + 1,
          separatorBuilder: (_, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Completed $doneCount of ${items.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            }
            final entry = items[index - 1];
            return ListTile(
              leading: _icon(context, entry.outcome),
              title: Text(entry.text),
              subtitle: Text(
                'Week ${entry.weekNumber} - ${_label(entry.outcome)} - ${formatShort(entry.at)}',
              ),
            );
          },
        ),
      ),
    );
  }

  static String _label(String outcome) {
    switch (outcome) {
      case 'done':
        return 'Completed';
      case 'replaced':
        return 'Replaced';
      default:
        return 'Dropped';
    }
  }

  static Widget _icon(BuildContext context, String outcome) {
    final muted = Theme.of(context).colorScheme.outline;
    switch (outcome) {
      case 'done':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'replaced':
        return Icon(Icons.swap_horiz, color: muted);
      default:
        return Icon(Icons.remove_circle_outline, color: muted);
    }
  }
}

class _SessionHistory extends StatelessWidget {
  const _SessionHistory();

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorWidgetOfExactType<HistoryScreen>();
    final sessions = screen!.store.studySessions;
    if (sessions.isEmpty) {
      return const Center(child: Text('No study sessions yet.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sessions.length,
      separatorBuilder: (_, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return ListTile(
          leading: Icon(
            session.completed ? Icons.check_circle : Icons.cancel_outlined,
            color: session.completed
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          title: Text(_modeLabel(session.mode)),
          subtitle: Text(
            '${_duration(session.actualSeconds)} - ${formatShort(session.endedAt)}',
          ),
          trailing: session.taskText == null
              ? null
              : const Icon(Icons.link, size: 18),
        );
      },
    );
  }

  static String _modeLabel(StudyMode mode) {
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

  static String _duration(int seconds) {
    final minutes = seconds ~/ 60;
    return '$minutes min focus';
  }
}

class _TimerStats extends StatelessWidget {
  const _TimerStats();

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorWidgetOfExactType<HistoryScreen>();
    final sessions = screen!.store.studySessions.where((e) => e.completed);
    final count = sessions.length;
    final totalSeconds = sessions.fold<int>(
      0,
      (total, session) => total + session.actualSeconds,
    );
    final planner = PlannerStats.fromHistory(screen.store.history);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _stat(context, 'Completed focus sessions', '$count'),
        const SizedBox(height: 12),
        _stat(context, 'Total focus time', '${totalSeconds ~/ 60} minutes'),
        const SizedBox(height: 12),
        _stat(
          context,
          'Average session',
          count == 0 ? '0 minutes' : '${totalSeconds ~/ count ~/ 60} minutes',
        ),
        const SizedBox(height: 12),
        _stat(context, 'Current weekly streak', '${planner.currentStreak} weeks'),
        const SizedBox(height: 12),
        _stat(context, 'Longest weekly streak', '${planner.longestStreak} weeks'),
        const SizedBox(height: 12),
        _stat(
          context,
          'Weekly completion rate',
          '${(planner.completionRate * 100).round()}%',
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
