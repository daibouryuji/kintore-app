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
                    ExpansionTile(
                      key: PageStorageKey('part_$p'),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text.rich(TextSpan(children: [
                        TextSpan(
                          text: p,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: '  ${items.length}種目',
                          style: theme.textTheme.bodySmall,
                        ),
                      ])),
                      children: [
                        for (final e in items)
                          ListTile(
                            contentPadding:
                                const EdgeInsets.only(left: 32, right: 16),
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
                                  builder: (_) =>
                                      ExerciseDetailPage(exercise: e)),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 1),
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
        for (final (date, sets) in history) {
          final v = store.bestE1rm(exercise.id, sets, date);
          if (v != null && (best == null || v > best)) best = v;
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
                  subtitle: Text(
                      '部位：${exercise.bodyPart} ・ ${loadTypeLabels[exercise.loadType] ?? ''}'),
                  onTap: () => editMemoDialog(context, exercise),
                ),
              ),
              if (best != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      _Stat(label: '最高推定1RM', value: '${fmt1(best)} kg'),
                      _Stat(label: '記録した日', value: '${history.length}日'),
                      _Stat(
                          label: '前回',
                          value: shortDate(history.first.$1)),
                    ]),
                  ),
                ),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('まだ記録がありません', textAlign: TextAlign.center),
                ),
              for (final (date, sets) in history)
                _HistoryCard(exercise: exercise, date: date, sets: sets),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(children: [
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

/// 1日分の記録：日付・その日の最高RM・ボリューム、セットごとの行
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.exercise,
    required this.date,
    required this.sets,
  });

  final Exercise exercise;
  final String date;
  final List<SetEntry> sets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final id = exercise.id;
    final repsOnly = exercise.loadType == loadRepsOnly;
    final dayBest = store.bestE1rm(id, sets, date);
    final volume =
        sets.fold(0.0, (a, s) => a + store.setVolume(id, s, date));
    final summary = repsOnly
        ? '合計 ${store.totalReps(sets)}回'
        : [
            if (dayBest != null) 'RM ${fmt1(dayBest)}kg',
            if (volume > 0) 'ボリューム ${fmtNum(volume.round())}kg',
          ].join('　');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(shortDate(date),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(summary,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ]),
            const Divider(height: 16),
            for (final (i, s) in sets.indexed)
              _setRow(theme, i + 1, s,
                  isBest: !repsOnly &&
                      dayBest != null &&
                      store.setE1rm(id, s, date) == dayBest),
          ],
        ),
      ),
    );
  }

  Widget _setRow(ThemeData theme, int n, SetEntry s, {required bool isBest}) {
    final rm = store.setE1rm(exercise.id, s, date);
    final load = exercise.loadType == loadBodyweight ||
            exercise.loadType == loadAssisted
        ? store.loadOf(exercise.id, s, date)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isBest
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
          ),
          child: Text('$n',
              style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isBest
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface)),
        ),
        const SizedBox(width: 12),
        Text(store.setLabel(exercise.id, s),
            style: theme.textTheme.bodyLarge),
        if (load != null)
          Text('（実負荷 ${fmt1(load)}kg）',
              style: theme.textTheme.bodySmall),
        const Spacer(),
        if (rm != null)
          Text('RM ${fmt1(rm)}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: isBest
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isBest ? FontWeight.bold : null)),
      ]),
    );
  }
}
