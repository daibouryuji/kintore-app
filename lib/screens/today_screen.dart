// 今日のメニューを表示して、セットごとに記録する画面。

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DateTime date = DateTime.now();

  /// まだ保存していないその日のトレーニング（メニューから組み立てたもの）
  Workout? draft;

  String get dateKey => fmtDate(date);
  bool get isToday => dateKey == fmtDate(DateTime.now());

  Workout get workout {
    final saved = store.workoutOn(dateKey);
    if (saved != null) return saved;
    if (draft == null || draft!.date != dateKey) {
      draft = _buildFromMenu(store.suggestedMenu(date));
    }
    return draft!;
  }

  /// 未保存のときは、メニューや前回記録の変更を反映するため毎回組み立て直す
  /// （入力を始めた時点で保存されるので、入力内容は失われない）
  void _refreshDraft() {
    if (store.workoutOn(dateKey) == null) {
      draft = _buildFromMenu(store.suggestedMenu(date));
    }
  }

  Workout _buildFromMenu(Menu? m) => Workout(
        id: newId(),
        date: dateKey,
        menuId: m?.id,
        logs: [
          if (m != null)
            for (final it in m.items) _logFor(it.exerciseId, it.sets),
        ],
      );

  /// 前回の重量・回数を最初から入れておく
  ExerciseLog _logFor(String exerciseId, int sets) {
    final last = store.lastSets(exerciseId, dateKey)?.$2 ?? const <SetEntry>[];
    return ExerciseLog(
      exerciseId: exerciseId,
      sets: List.generate(sets < 1 ? 1 : sets, (i) {
        final src = last.isEmpty ? null : last[i < last.length ? i : last.length - 1];
        return SetEntry(id: newId(), weight: src?.weight, reps: src?.reps);
      }),
    );
  }

  void _commit() => store.saveWorkout(workout);

  void _moveDate(int days) {
    setState(() {
      date = date.add(Duration(days: days));
      draft = null;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() {
        date = d;
        draft = null;
      });
    }
  }

  void _changeMenu(String? menuId) {
    final w = workout;
    final m = store.menu(menuId);
    if (w.hasDone) {
      // 記録済みのセットは残し、新しいメニューの種目を後ろに足す
      w.menuId = menuId;
      w.logs.removeWhere((l) =>
          l.doneSets.isEmpty &&
          !(m?.items.any((it) => it.exerciseId == l.exerciseId) ?? false));
      if (m != null) {
        for (final it in m.items) {
          if (!w.logs.any((l) => l.exerciseId == it.exerciseId)) {
            w.logs.add(_logFor(it.exerciseId, it.sets));
          }
        }
      }
    } else {
      final fresh = _buildFromMenu(m);
      w
        ..menuId = fresh.menuId
        ..logs = fresh.logs;
    }
    _commit();
  }

  Future<void> _addExercise() async {
    final ex = await pickExercise(context);
    if (ex == null) return;
    final target = store.menu(workout.menuId)?.items.where((it) => it.exerciseId == ex.id);
    workout.logs.add(_logFor(ex.id, (target != null && target.isNotEmpty) ? target.first.sets : 3));
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        _refreshDraft();
        final w = workout;
        final menu = store.menu(w.menuId);
        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: _pickDate,
              child: Text('${shortDate(dateKey)}${isToday ? '  今日' : ''}'),
            ),
            actions: [
              IconButton(
                  onPressed: () => _moveDate(-1),
                  icon: const Icon(Icons.chevron_left)),
              if (!isToday)
                TextButton(
                  onPressed: () => setState(() {
                    date = DateTime.now();
                    draft = null;
                  }),
                  child: const Text('今日'),
                ),
              IconButton(
                  onPressed: () => _moveDate(1),
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              _MenuSelector(
                workout: w,
                date: date,
                onChanged: _changeMenu,
              ),
              const SizedBox(height: 8),
              if (w.logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    '今日は休み、またはメニューに種目がありません。\n右下のボタンから種目を追加できます。',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final log in w.logs)
                ExerciseCard(
                  key: ObjectKey(log),
                  log: log,
                  date: dateKey,
                  target: _targetFor(menu, log.exerciseId),
                  onChanged: _commit,
                  onRemove: () async {
                    if (log.doneSets.isNotEmpty &&
                        !await confirmDialog(
                            context, '記録済みのセットがあります。この種目を外しますか？',
                            ok: '外す')) {
                      return;
                    }
                    w.logs.remove(log);
                    _commit();
                  },
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addExercise,
            icon: const Icon(Icons.add),
            label: const Text('種目を追加'),
          ),
        );
      },
    );
  }

  MenuItem? _targetFor(Menu? menu, String exerciseId) {
    if (menu == null) return null;
    for (final it in menu.items) {
      if (it.exerciseId == exerciseId) return it;
    }
    return null;
  }
}

class _MenuSelector extends StatelessWidget {
  const _MenuSelector({
    required this.workout,
    required this.date,
    required this.onChanged,
  });

  final Workout workout;
  final DateTime date;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final key = fmtDate(date);
    final current = store.menu(workout.menuId);
    final suggested = store.suggestedMenu(date);
    final since = current == null ? null : store.daysSinceMenu(current.id, key);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('メニュー：'),
              Expanded(
                child: DropdownButton<String?>(
                  value: current?.id,
                  isExpanded: true,
                  underline: const SizedBox(),
                  style: theme.textTheme.titleLarge,
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('休み／自由')),
                    for (final m in store.menus)
                      DropdownMenuItem<String?>(
                        value: m.id,
                        child: Text(m.weekday == null
                            ? m.name
                            : '${m.name}（${weekdayLabels[m.weekday! - 1]}）'),
                      ),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ]),
            if (current != null)
              Text(
                since == null ? '${current.name}：はじめて' : '前回の${current.name}：$since日前',
                style: theme.textTheme.bodySmall,
              ),
            if (suggested != null && suggested.id != current?.id)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onChanged(suggested.id),
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: Text(
                      '${store.rotationMode ? '順番どおりなら' : '曜日どおりなら'}「${suggested.name}」'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.log,
    required this.date,
    required this.target,
    required this.onChanged,
    required this.onRemove,
  });

  final ExerciseLog log;
  final String date;
  final MenuItem? target;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ex = store.exercise(log.exerciseId);
    final last = store.lastSets(log.exerciseId, date);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  ex?.name ?? '削除した種目',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (target != null)
                Text('目標 ${target!.sets}×${target!.reps}',
                    style: theme.textTheme.bodySmall),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'memo' && ex != null) editMemoDialog(context, ex);
                  if (v == 'remove') onRemove();
                },
                itemBuilder: (c) => [
                  if (ex != null)
                    const PopupMenuItem(value: 'memo', child: Text('メモを編集')),
                  const PopupMenuItem(value: 'remove', child: Text('今日のメニューから外す')),
                ],
              ),
            ]),
            if (ex != null && ex.memo.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 6),
                child: InkWell(
                  onTap: () => editMemoDialog(context, ex),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('📝 ${ex.memo}',
                        style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
                  ),
                ),
              ),
            if (last != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '前回 ${shortDate(last.$1)}：${last.$2.map((s) => s.label).join(', ')}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (var i = 0; i < log.sets.length; i++)
              SetRow(
                key: ObjectKey(log.sets[i]),
                index: i + 1,
                entry: log.sets[i],
                onChanged: onChanged,
                onDelete: () {
                  log.sets.removeAt(i);
                  onChanged();
                },
              ),
            TextButton.icon(
              onPressed: () {
                final prev = log.sets.isEmpty ? null : log.sets.last;
                log.sets.add(SetEntry(
                    id: newId(), weight: prev?.weight, reps: prev?.reps));
                onChanged();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('セット追加'),
            ),
          ],
        ),
      ),
    );
  }
}

class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.index,
    required this.entry,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final SetEntry entry;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final TextEditingController weight = TextEditingController(
      text: widget.entry.weight == null ? '' : fmtNum(widget.entry.weight!));
  late final TextEditingController reps =
      TextEditingController(text: widget.entry.reps?.toString() ?? '');

  @override
  void dispose() {
    weight.dispose();
    reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 4, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: e.done ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text('${widget.index}',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
                isDense: true, suffixText: 'kg', border: InputBorder.none),
            onChanged: (v) {
              e.weight = double.tryParse(v.replaceAll(',', '.'));
              widget.onChanged();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: reps,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
                isDense: true, suffixText: '回', border: InputBorder.none),
            onChanged: (v) {
              e.reps = int.tryParse(v);
              widget.onChanged();
            },
          ),
        ),
        Checkbox(
          value: e.done,
          onChanged: (v) {
            e.done = v ?? false;
            widget.onChanged();
          },
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close, size: 18),
          onPressed: widget.onDelete,
        ),
      ]),
    );
  }
}
