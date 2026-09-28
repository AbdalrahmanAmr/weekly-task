import 'package:flutter/material.dart';

import 'task_store.dart';
import 'week_utils.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.store});

  final TaskStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.history.reversed.toList();
          if (items.isEmpty) {
            return const Center(child: Text('No history yet.'));
          }
          final doneCount = items.where((e) => e.outcome == 'done').length;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView.separated(
                itemCount: items.length + 1,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Completed $doneCount of ${items.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  }
                  final e = items[i - 1];
                  return ListTile(
                    leading: _icon(context, e.outcome),
                    title: Text(e.text),
                    subtitle: Text(
                      'Week ${e.weekNumber} - ${_label(e.outcome)} - ${formatShort(e.at)}',
                    ),
                  );
                },
              ),
            ),
          );
        },
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
