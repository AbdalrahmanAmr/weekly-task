import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'history_screen.dart';
import 'study_timer.dart';
import 'study_timer_screen.dart';
import 'task_store.dart';
import 'week_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final TaskStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _taskCtrl = TextEditingController();
  final _nextCtrl = TextEditingController();
  Timer? _timer;
  bool _replacing = false;

  TaskStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check every 30s so the week rollover (and its notification) fires
    // even while the window is minimized.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await store.refresh();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _taskCtrl.dispose();
    _nextCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      store.refresh(notify: false).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  // ---- actions ----
  void _setTask() {
    final t = _taskCtrl.text.trim();
    if (t.isEmpty) return;
    store.setTask(t);
    _taskCtrl.clear();
  }

  void _setNext() {
    final t = _nextCtrl.text.trim();
    if (t.isEmpty) return;
    store.setNext(t);
    _nextCtrl.clear();
  }

  void _replace() {
    final t = _taskCtrl.text.trim();
    if (t.isEmpty) return;
    store.replaceTask(t);
    _taskCtrl.clear();
    setState(() => _replacing = false);
  }

  // ---- ui helpers ----
  Widget _wide(Widget child) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(width: double.infinity, child: child),
      );

  Widget _tile(BuildContext context, String label, String text,
      {Color? accent}) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: tt.labelSmall
                ?.copyWith(color: accent ?? cs.onSurfaceVariant, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(text, style: tt.titleMedium),
        ],
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, VoidCallback onSubmit) {
    return TextField(
      controller: ctrl,
      inputFormatters: [LengthLimitingTextInputFormatter(200)],
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: hint,
      ),
      onSubmitted: (_) => onSubmit(),
    );
  }

  Widget _weekCard(BuildContext context, WeekInfo w) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final left = w.daysLeft;
    final leftText = left == 0
        ? 'Last day of the week'
        : (left == 1 ? '1 day remaining' : '$left days remaining');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WEEK NUMBER',
                style: tt.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant, letterSpacing: 1)),
            Text('${w.number}',
                style: tt.displayLarge?.copyWith(
                    color: cs.primary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              'This week starts on ${formatLong(w.start)}\nto ${formatLong(w.end)}',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(leftText, style: tt.titleLarge),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (7 - left) / 7,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- states ----
  Widget _noTask(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("What's your task this week?", style: tt.titleLarge),
        const SizedBox(height: 4),
        const Text('One task. Make it count.'),
        const SizedBox(height: 12),
        _input(_taskCtrl, 'e.g. Finish the OWASP Top 10 labs', _setTask),
        _wide(FilledButton(
            onPressed: _setTask, child: const Text("Set this week's task"))),
      ],
    );
  }

  Widget _weekEnded(BuildContext context, Task c) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tile(context, "Last week's task", c.text),
        const SizedBox(height: 16),
        Text('Week ended. Not done yet.', style: tt.titleLarge),
        const SizedBox(height: 4),
        const Text('What now?'),
        _wide(FilledButton(
            onPressed: store.keepTask,
            child: const Text('Keep it for this week'))),
        _wide(OutlinedButton(
            onPressed: () => setState(() => _replacing = true),
            child: const Text('Replace it'))),
        _wide(TextButton(
          onPressed: store.dropTask,
          style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Drop it'),
        )),
        if (_replacing) ...[
          const SizedBox(height: 16),
          _input(_taskCtrl, 'New task for this week', _replace),
          _wide(FilledButton(
              onPressed: _replace, child: const Text('Save new task'))),
          _wide(TextButton(
              onPressed: () => setState(() => _replacing = false),
              child: const Text('Cancel'))),
        ],
      ],
    );
  }

  Widget _activeView(BuildContext context, Task c) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tile(context, "This week's task", c.text),
        _wide(FilledButton.icon(
          onPressed: store.complete,
          icon: const Icon(Icons.check),
          label: const Text('Mark as done'),
        )),
        const SizedBox(height: 20),
        if (store.next != null) ...[
          _tile(context, 'Queued for next week', store.next!),
          _wide(TextButton(
              onPressed: store.clearNext,
              child: const Text('Change next task'))),
        ] else ...[
          Text("Queue next week's task (optional)", style: tt.titleSmall),
          const SizedBox(height: 8),
          _input(_nextCtrl, 'Task for next week', _setNext),
          _wide(OutlinedButton(
              onPressed: _setNext, child: const Text('Queue it'))),
        ],
      ],
    );
  }

  Widget _doneView(BuildContext context, Task c) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tile(context, 'Completed', c.text, accent: Colors.green),
        const SizedBox(height: 16),
        if (store.next != null) ...[
          _tile(context, 'Next week', store.next!),
          _wide(TextButton(
              onPressed: store.clearNext,
              child: const Text('Change next task'))),
        ] else ...[
          Text("Nice work. What's next week's task?", style: tt.titleMedium),
          const SizedBox(height: 8),
          _input(_nextCtrl, 'Task for next week', _setNext),
          _wide(FilledButton(
              onPressed: _setNext,
              child: const Text('Lock it in for next week'))),
        ],
      ],
    );
  }

  Widget _body(BuildContext context, WeekInfo w) {
    final c = store.current;
    if (c == null) return _noTask(context);
    if (c.weekKey != w.key && !c.done) return _weekEnded(context, c);
    if (c.done) return _doneView(context, c);
    return _activeView(context, c);
  }

  Widget _timerTile(BuildContext context) {
    final active = store.activeStudyTimer;
    if (active == null) {
      return OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StudyTimerScreen(store: store)),
        ),
        icon: const Icon(Icons.timer_outlined),
        label: const Text('Start a study session'),
      );
    }
    final phase = active.phase == StudyPhase.focus ? 'Focus' : 'Break';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.timer),
        title: Text('$phase session active'),
        subtitle: Text(active.taskText ?? 'General study session'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StudyTimerScreen(store: store)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Task'),
        actions: [
          IconButton(
            tooltip: 'Study timer',
            icon: const Icon(Icons.timer_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => StudyTimerScreen(store: store)),
            ),
          ),
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => HistoryScreen(store: store)),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final w = WeekInfo.now();
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _weekCard(context, w),
                  const SizedBox(height: 16),
                  _timerTile(context),
                  const SizedBox(height: 16),
                  _body(context, w),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
