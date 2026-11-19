// バックアップ（書き出し・読み込み）。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store.dart';
import '../widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showText(BuildContext context, String title, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) showSnack(context, 'コピーしました');
    } catch (_) {
      // コピーできない環境でも、下のダイアログから手で選択してコピーできる
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(child: SelectableText(text)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('閉じる')),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final input = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('バックアップから復元'),
        content: TextField(
          controller: input,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '書き出したバックアップ（JSON）を貼り付け',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('復元')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (!await confirmDialog(context, '今のデータはすべて置き換わります。よろしいですか？',
        ok: '置き換える')) {
      return;
    }
    try {
      store.importJson(input.text);
      if (context.mounted) showSnack(context, '復元しました');
    } catch (e) {
      if (context.mounted) showSnack(context, '読み込めませんでした：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定・バックアップ')),
      body: ListView(children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'データはこのiPhoneの中にだけ保存されています。'
            '機種変更やブラウザのデータ削除に備えて、ときどきバックアップを書き出して、メモアプリなどに貼っておいてください。',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: const Text('バックアップを書き出す'),
          subtitle: const Text('全データをコピーします（JSON）'),
          onTap: () => _showText(context, 'バックアップ', store.exportJson()),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('バックアップから復元'),
          onTap: () => _import(context),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('記録をCSVでコピー'),
          subtitle: const Text('スプレッドシートに貼ったり、分析を頼むとき用'),
          onTap: () => _showText(context, 'CSV', store.exportCsv()),
        ),
      ]),
    );
  }
}
