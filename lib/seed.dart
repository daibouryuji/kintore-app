// 初回起動時に入れておく PPL＋上半身/下半身 のメニュー。
// アプリ上で自由に変更・削除できます。

import 'models.dart';
import 'store.dart';

void seedData(Store s) {
  final byName = <String, Exercise>{};

  MenuItem i(String name, String part, int sets, String reps,
      {String load = loadNormal}) {
    final ex = byName.putIfAbsent(name,
        () => Exercise(id: newId(), name: name, bodyPart: part, loadType: load));
    return MenuItem(exerciseId: ex.id, sets: sets, reps: reps);
  }

  s.menus = [
    Menu(id: newId(), name: 'プッシュ', weekday: 1, items: [
      i('ベンチプレス', '胸', 4, '6〜8'),
      i('インクラインダンベルプレス', '胸', 3, '8〜10'),
      i('ショルダープレス', '肩', 3, '8〜10'),
      i('サイドレイズ', '肩', 3, '12〜15'),
      i('ケーブルフライ', '胸', 3, '12〜15'),
      i('トライセプスプレスダウン', '腕', 3, '10〜12'),
      i('オーバーヘッドエクステンション', '腕', 2, '12〜15'),
    ]),
    Menu(id: newId(), name: 'プル', weekday: 2, items: [
      i('懸垂', '背中', 4, '6〜10', load: loadBodyweight),
      i('バーベルローイング', '背中', 3, '8〜10'),
      i('シーテッドケーブルロー', '背中', 3, '10〜12'),
      i('フェイスプル', '肩', 3, '12〜15'),
      i('バーベルカール', '腕', 3, '8〜10'),
      i('ハンマーカール', '腕', 2, '10〜12'),
    ]),
    Menu(id: newId(), name: '脚', weekday: 3, items: [
      i('スクワット', '脚', 4, '6〜8'),
      i('ルーマニアンデッドリフト', '脚', 3, '8〜10'),
      i('レッグプレス', '脚', 3, '10〜12'),
      i('レッグカール', '脚', 3, '10〜12'),
      i('レッグエクステンション', '脚', 2, '12〜15'),
      i('カーフレイズ', '脚', 3, '12〜15'),
    ]),
    Menu(id: newId(), name: '上半身', weekday: 5, items: [
      i('インクラインベンチプレス', '胸', 3, '6〜8'),
      i('ワンハンドダンベルロー', '背中', 3, '8〜10'),
      i('ダンベルショルダープレス', '肩', 3, '8〜10'),
      i('ラットプルダウン', '背中', 3, '10〜12'),
      i('サイドレイズ', '肩', 3, '12〜15'),
      i('インクラインダンベルカール', '腕', 2, '10〜12'),
      i('ディップス', '腕', 2, '10〜12', load: loadBodyweight),
    ]),
    Menu(id: newId(), name: '下半身', weekday: 6, items: [
      i('デッドリフト', '脚', 3, '6〜8'),
      i('ブルガリアンスクワット', '脚', 3, '8〜10'),
      i('ハックスクワット', '脚', 3, '10〜12'),
      i('シーテッドレッグカール', '脚', 3, '10〜12'),
      i('カーフレイズ', '脚', 3, '12〜15'),
      i('アブローラー', '腹', 3, '10〜15', load: loadRepsOnly),
    ]),
  ];
  s.exercises = byName.values.toList();
}
