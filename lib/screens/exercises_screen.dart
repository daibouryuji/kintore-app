// 種目の一覧・追加・メモ・履歴。

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';

class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: Text('種目（${store.exercises.length}）')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final p in bodyParts)
                ...() {
                  final items = store.exercises
                      .where((e) => e.bodyPart == p ||
                          (p == 'その他' && !bodyParts.contains(e.bodyPart)))
                      .toList();
                  if (items.isEmpty) return <Widget>[];
                  return <Widget>[
                    PartHeader(p),
                    for (final e in items)
                      ListTile(
                        title: Text(e.name),
                        subtitle: e.memo.isEmpty
                            ? null
                            : Text('📝 ${e.memo}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: theme.colorScheme.tertiary)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ExerciseDetailPage(exercise: e)),
                        ),
                      ),
                  ];
                }(),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showExerciseDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('種目を追加'),
          ),
        );
      },
    );
  }
}

class ExerciseDetailPage extends StatelessWidget {
  const ExerciseDetailPage({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final history = store.history(exercise.id);
        double? best;
        for (final (_, sets) in history) {
          for (final s in sets) {
            final w = s.weight ?? 0;
            if (best == null || w > best) best = w;
          }
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(exercise.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => showExerciseDialog(context, ex: exercise),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await confirmDialog(context,
                      '「${exercise.name}」を削除しますか？\nメニューからも外れます。過去の記録は残ります。',
                      ok: '削除');
                  if (!ok || !context.mounted) return;
                  store.deleteExercise(exercise.id);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.sticky_note_2_outlined),
                  title: Text(exercise.memo.isEmpty ? 'メモなし（タップで追加）' : exercise.memo),
                  subtitle: Text('部位：${exercise.bodyPart}'),
                  onTap: () => editMemoDialog(context, exercise),
                ),
              ),
              if (best != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('最高重量：${fmtNum(best)} kg',
                      style: theme.textTheme.titleMedium),
                ),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('まだ記録がありません', textAlign: TextAlign.center),
                ),
              for (final (date, sets) in history)
                ListTile(
                  dense: true,
                  title: Text(shortDate(date)),
                  subtitle: Text(sets.map((s) => s.label).join(', ')),
                ),
            ],
          ),
        );
      },
    );
  }
}
