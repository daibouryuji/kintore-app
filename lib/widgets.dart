// 複数の画面で使うダイアログなど。

import 'package:flutter/material.dart';

import 'models.dart';
import 'store.dart';

Future<bool> confirmDialog(BuildContext context, String message,
    {String ok = 'OK'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('キャンセル')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

void showSnack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// 種目の追加・編集。ex が null なら新規作成し、作った種目を返す。
Future<Exercise?> showExerciseDialog(BuildContext context,
    {Exercise? ex}) async {
  final name = TextEditingController(text: ex?.name ?? '');
  final memo = TextEditingController(text: ex?.memo ?? '');
  var part = ex?.bodyPart ?? '胸';
  if (!bodyParts.contains(part)) part = 'その他';

  final saved = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(ex == null ? '種目を追加' : '種目を編集'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              autofocus: ex == null,
              decoration: const InputDecoration(labelText: '種目名'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: part,
              decoration: const InputDecoration(labelText: '部位'),
              items: [
                for (final p in bodyParts)
                  DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (v) => setState(() => part = v ?? part),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: memo,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'メモ',
                hintText: '例：セーフティの高さ9',
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('保存')),
        ],
      ),
    ),
  );

  if (saved != true || name.text.trim().isEmpty) return null;
  if (ex == null) {
    final created = Exercise(
      id: newId(),
      name: name.text.trim(),
      bodyPart: part,
      memo: memo.text.trim(),
    );
    store.addExercise(created);
    return created;
  }
  ex
    ..name = name.text.trim()
    ..bodyPart = part
    ..memo = memo.text.trim();
  store.changed();
  return ex;
}

Future<void> editMemoDialog(BuildContext context, Exercise ex) async {
  final memo = TextEditingController(text: ex.memo);
  final saved = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('${ex.name} のメモ'),
      content: TextField(
        controller: memo,
        autofocus: true,
        maxLines: 4,
        minLines: 1,
        decoration: const InputDecoration(hintText: '例：セーフティの高さ9'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('キャンセル')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true), child: const Text('保存')),
      ],
    ),
  );
  if (saved == true) {
    ex.memo = memo.text.trim();
    store.changed();
  }
}

/// 種目を1つ選ぶ（その場で新しい種目も作れる）
Future<Exercise?> pickExercise(BuildContext context) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => const _ExercisePicker(),
  );
}

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker();

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final list = store.exercises
        .where((e) => query.isEmpty || e.name.contains(query))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '種目を検索',
            ),
            onChanged: (v) => setState(() => query = v.trim()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.add),
          title: const Text('新しい種目を作る'),
          onTap: () async {
            final created = await showExerciseDialog(context);
            if (created != null && context.mounted) {
              Navigator.pop(context, created);
            }
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(children: [
            for (final p in bodyParts)
              ...() {
                final items = list.where((e) => e.bodyPart == p).toList();
                if (items.isEmpty) return <Widget>[];
                return <Widget>[
                  _PartHeader(p),
                  for (final e in items)
                    ListTile(
                      title: Text(e.name),
                      onTap: () => Navigator.pop(context, e),
                    ),
                ];
              }(),
          ]),
        ),
      ]),
    );
  }
}

class _PartHeader extends StatelessWidget {
  const _PartHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class PartHeader extends _PartHeader {
  const PartHeader(super.text);
}
