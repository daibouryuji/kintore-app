// 今日のメニューを表示して、セットごとに記録する画面。

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'calendar_screen.dart';
import 'exercises_screen.dart';

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

  /// 空のセットを目標セット数だけ用意する
  ExerciseLog _logFor(String exerciseId, int sets) => ExerciseLog(
        exerciseId: exerciseId,
        sets: List.generate(sets < 1 ? 1 : sets, (_) => SetEntry(id: newId())),
      );

  void _commit() => store.saveWorkout(workout);
  void _commitQuiet() => store.updateWorkoutQuiet(workout);

  void _moveDate(int days) {
    setState(() {
      date = date.add(Duration(days: days));
      draft = null;
    });
  }

  /// カレンダーを開き、選んだ日に移動する
  Future<void> _pickDate() async {
    final d = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(builder: (_) => CalendarPage(selected: date)),
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
                  tooltip: 'カレンダー',
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month)),
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
              if (w.logs.isNotEmpty)
                ListenableBuilder(
                  listenable: store.workoutTick,
                  builder: (context, _) => _DaySummary(workout: w),
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
                  onEdited: _commitQuiet,
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
    final showHint = suggested?.id != current?.id;

    Widget chip(String? id, String label, {String? sub}) {
      final selected = id == current?.id;
      final isSuggested = id == suggested?.id;
      return ChoiceChip(
        selected: selected,
        showCheckmark: false,
        avatar: isSuggested && !selected
            ? const Icon(Icons.lightbulb_outline, size: 18)
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        label: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: label,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (sub != null)
              TextSpan(text: ' $sub', style: theme.textTheme.labelSmall),
          ]),
        ),
        onSelected: (_) {
          if (!selected) onChanged(id);
        },
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in store.menus)
                  chip(m.id, m.name,
                      sub: m.weekday == null
                          ? null
                          : weekdayLabels[m.weekday! - 1]),
                chip(null, '休み'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (current != null)
                  since == null
                      ? '${current.name}は今回がはじめて'
                      : '前回の${current.name}：$since日前',
                if (showHint)
                  '💡 ${store.rotationMode ? '順番' : '曜日'}どおりなら「${suggested?.name ?? '休み'}」',
              ].join('　'),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = workout;
    final prev = w.menuId == null
        ? null
        : store.previousWorkoutOfMenu(w.menuId!, w.date);
    final vol = store.workoutVolume(w);
    String? diff;
    if (prev != null && vol > 0) {
      final d = vol - store.workoutVolume(prev);
      diff = '前回比 ${d >= 0 ? '+' : ''}${fmtNum(d.round())}kg';
    }

    Widget stat(String label, String value, {String? sub}) => Expanded(
          child: Column(children: [
            Text(label, style: theme.textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (sub != null)
              Text(sub,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary)),
          ]),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(children: [
          stat('完了セット', '${w.doneSetCount} / ${w.setCount}'),
          stat('総ボリューム', '${fmtNum(vol.round())} kg', sub: diff),
          stat('種目', '${w.logs.where((l) => l.doneSets.isNotEmpty).length} / ${w.logs.length}'),
        ]),
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
    required this.onEdited,
    required this.onRemove,
  });

  final ExerciseLog log;
  final String date;
  final MenuItem? target;

  /// セットの追加・削除など（画面全体を更新）
  final VoidCallback onChanged;

  /// セットの数字の入力（このカードだけ更新）
  final VoidCallback onEdited;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store.workoutTick,
        builder: (context, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final ex = store.exercise(log.exerciseId);
    final last = store.lastSets(log.exerciseId, date);
    final todayBest = store.bestE1rm(log.exerciseId, log.doneSets, date);
    final lastBest =
        last == null ? null : store.bestE1rm(log.exerciseId, last.$2, last.$1);
    final type = ex?.loadType ?? loadNormal;
    final bw = store.bodyWeightOn(date);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: ex == null
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ExerciseDetailPage(exercise: ex)),
                            ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                          child: Text(
                            ex?.name ?? '削除した種目',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (ex != null)
                          Icon(Icons.chevron_right,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant),
                      ]),
                    ),
                  ),
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
            if (type == loadRepsOnly && log.doneSets.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '合計 ${store.totalReps(log.doneSets)}回'
                  '${last == null ? '' : '（前回 ${store.totalReps(last.$2)}回）'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
              ),
            if (type == loadBodyweight || type == loadAssisted)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  bw == null
                      ? '⚠ 体重が未記録のため実負荷を計算できません（体重タブで記録）'
                      : type == loadAssisted
                          ? '実負荷 = 体重 ${fmtNum(bw)}kg − アシスト'
                          : '実負荷 = 体重 ${fmtNum(bw)}kg ＋ 加重',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: bw == null
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant),
                ),
              ),
            if (last != null && todayBest == null && log.doneSets.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('前回 ${shortDate(last.$1)}',
                    style: theme.textTheme.bodySmall),
              ),
            if (todayBest != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: '推定1RM ${fmt1(todayBest)}kg',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (lastBest != null)
                      TextSpan(
                        text: '（前回 ${fmt1(lastBest)}kg ${_signed(todayBest - lastBest)}）',
                      ),
                    TextSpan(
                        text:
                            '　ボリューム ${fmtNum(store.logVolume(log, date).round())}kg'),
                  ]),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            for (var i = 0; i < log.sets.length; i++)
              SetRow(
                key: ObjectKey(log.sets[i]),
                index: i + 1,
                entry: log.sets[i],
                exerciseId: log.exerciseId,
                date: date,
                previous: last == null
                    ? null
                    : last.$2[i < last.$2.length ? i : last.$2.length - 1],
                onChanged: onEdited,
                onDelete: () {
                  log.sets.removeAt(i);
                  onChanged();
                },
              ),
            TextButton.icon(
              onPressed: () {
                log.sets.add(SetEntry(id: newId()));
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
    required this.exerciseId,
    required this.date,
    required this.previous,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final SetEntry entry;
  final String exerciseId;
  final String date;

  /// 前回の同じセット番号の記録（タップで入力欄にコピー）
  final SetEntry? previous;
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

  void _copyPrevious() {
    final p = widget.previous;
    if (p == null) return;
    final e = widget.entry;
    e
      ..weight = p.weight
      ..reps = p.reps;
    weight.text = p.weight == null ? '' : fmtNum(p.weight!);
    reps.text = p.reps?.toString() ?? '';
    widget.onChanged();
  }

  InputDecoration _deco(String hint, String suffix, ThemeData theme) =>
      InputDecoration(
        isDense: true,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        hintText: hint,
        suffixText: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final theme = Theme.of(context);
    final type = store.loadTypeOf(widget.exerciseId);
    final rm = store.setE1rm(widget.exerciseId, e, widget.date);
    final load = type == loadNormal
        ? null
        : store.loadOf(widget.exerciseId, e, widget.date);
    final prev = widget.previous;
    final hint = switch (type) {
      loadBodyweight => '加重',
      loadAssisted => 'アシスト',
      _ => '重量',
    };
    return Container(
      margin: const EdgeInsets.only(right: 4, top: 3, bottom: 3),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: e.done
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: Text('${widget.index}',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        ),
        if (type == loadRepsOnly)
          const SizedBox(width: 4)
        else ...[
        SizedBox(
          width: 104,
          child: TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            decoration: _deco(hint, 'kg', theme),
            onChanged: (v) {
              e.weight = double.tryParse(v.replaceAll(',', '.'));
              widget.onChanged();
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('×'),
        ),
        ],
        SizedBox(
          width: 84,
          child: TextField(
            controller: reps,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            decoration: _deco('回数', '回', theme),
            onChanged: (v) {
              e.reps = int.tryParse(v);
              widget.onChanged();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (prev != null)
                InkWell(
                  onTap: _copyPrevious,
                  child: Text(
                    '前回 ${store.setLabel(widget.exerciseId, prev)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              if (rm != null)
                Text(
                  load == null
                      ? 'RM ${fmt1(rm)}'
                      : '実負荷 ${fmt1(load)} ・ RM ${fmt1(rm)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
            ],
          ),
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

String _signed(double d) {
  final r = (d * 10).round() / 10;
  if (r == 0) return '±0';
  return r > 0 ? '+${fmtNum(r)}' : fmtNum(r);
}
