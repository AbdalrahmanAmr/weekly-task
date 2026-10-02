import 'package:flutter/material.dart';

import 'task_store.dart';
import 'week_utils.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.store});

  final TaskStore store;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _yearView = false;

  Map<String, HistoryEntry> get _weeks {
    final result = <String, HistoryEntry>{};
    for (final entry in widget.store.history) {
      if (entry.weekKey != null) result[entry.weekKey!] = entry;
    }
    return result;
  }

  String _monthName(int month) => formatLong(DateTime(2026, month, 1)).split(',').last.trim().split(' ').first;

  Color _color(BuildContext context, HistoryEntry? entry) {
    if (entry == null) return Theme.of(context).colorScheme.surfaceContainerHighest;
    if (entry.outcome == 'done') return Colors.green.withValues(alpha: .25);
    if (entry.outcome == 'dropped') return Colors.red.withValues(alpha: .2);
    return Colors.amber.withValues(alpha: .25);
  }

  void _showWeek(HistoryEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.text),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Week ${entry.weekNumber} - ${entry.outcome}'),
            if (entry.subtasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final subtask in entry.subtasks)
                Text('${subtask.text}: ${subtask.completedDays.length} days'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _weekCell(BuildContext context, DateTime week) {
    final entry = _weeks[dateKey(week)];
    return InkWell(
      onTap: entry == null ? null : () => _showWeek(entry),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _color(context, entry),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('W${entry?.weekNumber ?? WeekInfo.of(week).number}'),
            const SizedBox(height: 6),
            Text(entry?.text ?? 'No recorded task', maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  List<DateTime> _weeksInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    var week = WeekInfo.of(first).start;
    final result = <DateTime>[];
    while (!week.isAfter(last)) {
      result.add(week);
      week = week.add(const Duration(days: 7));
    }
    return result;
  }

  Widget _monthView(BuildContext context) {
    final weeks = _weeksInMonth(_month);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left)),
            Text('${_monthName(_month.month)} ${_month.year}', style: Theme.of(context).textTheme.titleLarge),
            IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: 120,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: weeks.length,
            itemBuilder: (context, index) => _weekCell(context, weeks[index]),
          ),
        ),
      ],
    );
  }

  Widget _yearOverview(BuildContext context) {
    final year = _month.year;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(onPressed: () => setState(() => _month = DateTime(year - 1)), icon: const Icon(Icons.chevron_left)),
            Text('$year', style: Theme.of(context).textTheme.titleLarge),
            IconButton(onPressed: () => setState(() => _month = DateTime(year + 1)), icon: const Icon(Icons.chevron_right)),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisExtent: 100,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            final month = DateTime(year, index + 1);
            final recorded = _weeksInMonth(month)
                .map((week) => _weeks[dateKey(week)])
                .whereType<HistoryEntry>()
                .length;
            return InkWell(
              onTap: () => setState(() {
                _month = month;
                _yearView = false;
              }),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_monthName(index + 1)),
                      const Spacer(),
                      Text('$recorded recorded weeks'),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planner calendar'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Month')),
                ButtonSegment(value: true, label: Text('Year')),
              ],
              selected: {_yearView},
              onSelectionChanged: (value) => setState(() => _yearView = value.first),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => _yearView ? _yearViewWidget(context) : _monthView(context),
      ),
    );
  }

  Widget _yearViewWidget(BuildContext context) =>
      _yearView ? _yearOverview(context) : _monthView(context);
}
