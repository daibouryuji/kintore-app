// メニュー（プッシュ・プルなど）の登録と、曜日・順番の設定。

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';

class MenusScreen extends StatelessWidget {
  const MenusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('メニュー')),
          body: Column(children: [
            SwitchListTile(
              title: const Text('順番モード'),
              subtitle: const Text('曜日ではなく、前回やったメニューの次を提案します。順番は下の並び順です。'),
              value: store.rotationMode,
              onChanged: (v) {
                store.rotationMode = v;
                store.changed();
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ReorderableListView(
                padding: const EdgeInsets.only(bottom: 96),
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) newIndex--;
                  final m = store.menus.removeAt(oldIndex);
                  store.menus.insert(newIndex, m);
                  store.changed();
                },
                children: [
                  for (final m in store.menus)
                    ListTile(
                      key: ValueKey(m.id),
                      title: Text(m.name),
                      subtitle: Text(
                          '${m.weekday == null ? '曜日なし' : '${weekdayLabels[m.weekday! - 1]}曜日'} ・ ${m.items.length}種目'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MenuEditPage(menu: m)),
                      ),
                    ),
                ],
              ),
            ),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              final m = Menu(id: newId(), name: '新しいメニュー');
              store.menus.add(m);
              store.changed();
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => MenuEditPage(menu: m)));
            },
            icon: const Icon(Icons.add),
            label: const Text('メニューを追加'),
          ),
        );
      },
    );
  }
}

class MenuEditPage extends StatefulWidget {
  const MenuEditPage({super.key, required this.menu});

  final Menu menu;

  @override
  State<MenuEditPage> createState() => _MenuEditPageState();
}

class _MenuEditPageState extends State<MenuEditPage> {
  late final TextEditingController name =
      TextEditingController(text: widget.menu.name);

  Menu get m => widget.menu;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _editItem(MenuItem it) async {
    final sets = TextEditingController(text: '${it.sets}');
    final reps = TextEditingController(text: it.reps);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(store.exercise(it.exerciseId)?.name ?? ''),
        content: Row(children: [
          Expanded(
            child: TextField(
              controller: sets,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'セット数'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: reps,
              decoration: const InputDecoration(
                  labelText: '回数', hintText: '8〜10'),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      it.sets = int.tryParse(sets.text) ?? it.sets;
      it.reps = reps.text.trim();
      store.changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('メニューを編集'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final ok = await confirmDialog(
                      context, '「${m.name}」を削除しますか？\n過去の記録は残ります。',
                      ok: '削除');
                  if (!ok || !context.mounted) return;
                  store.menus.remove(m);
                  store.changed();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          body: ReorderableListView(
            padding: const EdgeInsets.only(bottom: 96),
            header: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'メニュー名'),
                    onChanged: (v) {
                      m.name = v.trim().isEmpty ? '無題' : v.trim();
                      store.changed();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: m.weekday,
                    decoration: const InputDecoration(labelText: '基本の曜日'),
                    items: [
                      const DropdownMenuItem<int?>(
                          value: null, child: Text('なし')),
                      for (var d = 1; d <= 7; d++)
                        DropdownMenuItem<int?>(
                            value: d, child: Text('${weekdayLabels[d - 1]}曜日')),
                    ],
                    onChanged: (v) {
                      m.weekday = v;
                      store.changed();
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('種目（長押しで並べ替え、タップでセット数・回数を変更）',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex--;
              final it = m.items.removeAt(oldIndex);
              m.items.insert(newIndex, it);
              store.changed();
            },
            children: [
              for (final it in m.items)
                ListTile(
                  key: ObjectKey(it),
                  title: Text(store.exercise(it.exerciseId)?.name ?? '削除した種目'),
                  subtitle: Text('${it.sets}セット × ${it.reps}'),
                  onTap: () => _editItem(it),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      m.items.remove(it);
                      store.changed();
                    },
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final ex = await pickExercise(context);
              if (ex == null) return;
              m.items.add(MenuItem(exerciseId: ex.id));
              store.changed();
            },
            icon: const Icon(Icons.add),
            label: const Text('種目を追加'),
          ),
        );
      },
    );
  }
}
