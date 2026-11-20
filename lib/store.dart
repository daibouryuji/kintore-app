// アプリ全体のデータを持ち、端末（ブラウザ）に保存するクラス。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'seed.dart';

final store = Store();

class Store extends ChangeNotifier {
  static const _key = 'kintore_data_v1';

  List<Exercise> exercises = [];
  List<Menu> menus = []; // この並び順が「順番モード」で回る順番
  List<Workout> workouts = []; // 日付順
  List<BodyWeight> bodyWeights = []; // 日付順
  bool rotationMode = false;

  SharedPreferences? _prefs;
  Timer? _saveTimer;

  /// セットの数字を打っているときだけ通知する（記録カードだけが描き直される）
  final workoutTick = ValueNotifier<int>(0);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) {
      seedData(this);
      await _save();
    } else {
      _fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    }
    notifyListeners();
  }

  /// 中身を変えたら必ず呼ぶ。画面の更新と保存を行う。
  void changed() {
    notifyListeners();
    _scheduleSave();
  }

  /// 保存は、変更が0.5秒止まってからまとめて行う
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _save);
  }

  /// 保存待ちがあればすぐ保存する（アプリが裏に回るときなど）
  Future<void> flush() async {
    if (_saveTimer == null) return;
    _saveTimer!.cancel();
    _saveTimer = null;
    await _save();
  }

  Future<void> _save() async {
    _saveTimer = null;
    await _prefs?.setString(_key, jsonEncode(toJson()));
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'rotationMode': rotationMode,
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'menus': menus.map((e) => e.toJson()).toList(),
        'workouts': workouts.map((e) => e.toJson()).toList(),
        'bodyWeights': bodyWeights.map((e) => e.toJson()).toList(),
      };

  List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
      ((v as List?) ?? [])
          .map((e) => f(Map<String, dynamic>.from(e as Map)))
          .toList();

  void _fromJson(Map<String, dynamic> j) {
    rotationMode = (j['rotationMode'] as bool?) ?? false;
    exercises = _list(j['exercises'], Exercise.fromJson);
    menus = _list(j['menus'], Menu.fromJson);
    workouts = _list(j['workouts'], Workout.fromJson)
      ..sort((a, b) => a.date.compareTo(b.date));
    bodyWeights = _list(j['bodyWeights'], BodyWeight.fromJson)
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // ---------- 種目 ----------

  Exercise? exercise(String id) {
    for (final e in exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  void addExercise(Exercise e) {
    exercises.add(e);
    changed();
  }

  /// 種目を消す。メニューからは外すが、過去の記録は残す。
  void deleteExercise(String id) {
    exercises.removeWhere((e) => e.id == id);
    for (final m in menus) {
      m.items.removeWhere((it) => it.exerciseId == id);
    }
    changed();
  }

  /// その日より前で、最後にやったときのセット（チェック済みのみ）
  (String, List<SetEntry>)? lastSets(String exerciseId, String beforeDate) {
    for (final w in workouts.reversed) {
      if (w.date.compareTo(beforeDate) >= 0) continue;
      for (final l in w.logs) {
        if (l.exerciseId != exerciseId) continue;
        final done = l.doneSets;
        if (done.isNotEmpty) return (w.date, done);
      }
    }
    return null;
  }

  /// 新しい順の履歴
  List<(String, List<SetEntry>)> history(String exerciseId) {
    final result = <(String, List<SetEntry>)>[];
    for (final w in workouts.reversed) {
      for (final l in w.logs) {
        if (l.exerciseId != exerciseId) continue;
        final done = l.doneSets;
        if (done.isNotEmpty) result.add((w.date, done));
      }
    }
    return result;
  }

  // ---------- メニュー ----------

  Menu? menu(String? id) {
    if (id == null) return null;
    for (final m in menus) {
      if (m.id == id) return m;
    }
    return null;
  }

  Menu? menuForWeekday(int weekday) {
    for (final m in menus) {
      if (m.weekday == weekday) return m;
    }
    return null;
  }

  /// その日に提案するメニュー。null なら休み。
  Menu? suggestedMenu(DateTime date) {
    if (!rotationMode) return menuForWeekday(date.weekday);
    if (menus.isEmpty) return null;
    final key = fmtDate(date);
    for (final w in workouts.reversed) {
      if (w.date.compareTo(key) >= 0 || !w.hasDone) continue;
      final i = menus.indexWhere((m) => m.id == w.menuId);
      if (i < 0) continue;
      return menus[(i + 1) % menus.length];
    }
    return menuForWeekday(date.weekday) ?? menus.first;
  }

  /// そのメニューを最後にやってから何日経ったか
  int? daysSinceMenu(String menuId, String date) {
    for (final w in workouts.reversed) {
      if (w.date.compareTo(date) >= 0) continue;
      if (w.menuId == menuId && w.hasDone) {
        return DateTime.parse(date).difference(DateTime.parse(w.date)).inDays;
      }
    }
    return null;
  }

  // ---------- トレーニング ----------

  Workout? workoutOn(String date) {
    for (final w in workouts) {
      if (w.date == date) return w;
    }
    return null;
  }

  /// その日より前で、同じメニューを最後にやった日
  Workout? previousWorkoutOfMenu(String menuId, String date) {
    for (final w in workouts.reversed) {
      if (w.date.compareTo(date) < 0 && w.menuId == menuId && w.hasDone) {
        return w;
      }
    }
    return null;
  }

  /// セットの数字の入力用：画面全体ではなく記録カードだけを更新する
  void updateWorkoutQuiet(Workout w) {
    if (!workouts.contains(w)) {
      workouts.removeWhere((x) => x.date == w.date);
      workouts.add(w);
      workouts.sort((a, b) => a.date.compareTo(b.date));
    }
    workoutTick.value++;
    _scheduleSave();
  }

  void saveWorkout(Workout w) {
    if (!workouts.contains(w)) {
      workouts.removeWhere((x) => x.date == w.date);
      workouts.add(w);
      workouts.sort((a, b) => a.date.compareTo(b.date));
    }
    changed();
  }

  // ---------- 負荷・1RM・ボリューム ----------

  /// その日時点の体重（その日以前で最新。なければ最初の記録）
  double? bodyWeightOn(String date) {
    BodyWeight? found;
    for (final b in bodyWeights) {
      if (b.date.compareTo(date) > 0) break;
      found = b;
    }
    found ??= bodyWeights.isEmpty ? null : bodyWeights.first;
    return found?.kg;
  }

  String loadTypeOf(String exerciseId) =>
      exercise(exerciseId)?.loadType ?? loadNormal;

  /// 実際にかかった負荷。自重・アシストで体重が未記録なら null。
  double? loadOf(String exerciseId, SetEntry s, String date) {
    final type = loadTypeOf(exerciseId);
    if (type == loadRepsOnly) return null;
    if (type == loadNormal) return s.weight;
    final bw = bodyWeightOn(date);
    if (bw == null) return null;
    final input = s.weight ?? 0;
    return type == loadAssisted ? bw - input : bw + input;
  }

  double? setE1rm(String exerciseId, SetEntry s, String date) =>
      e1rmOf(loadOf(exerciseId, s, date), s.reps);

  double setVolume(String exerciseId, SetEntry s, String date) =>
      (loadOf(exerciseId, s, date) ?? 0) * (s.reps ?? 0);

  double logVolume(ExerciseLog l, String date) => l.doneSets
      .fold(0.0, (a, s) => a + setVolume(l.exerciseId, s, date));

  double workoutVolume(Workout w) =>
      w.logs.fold(0.0, (a, l) => a + logVolume(l, w.date));

  double? bestE1rm(String exerciseId, Iterable<SetEntry> sets, String date) {
    double? best;
    for (final s in sets) {
      final v = setE1rm(exerciseId, s, date);
      if (v != null && (best == null || v > best)) best = v;
    }
    return best;
  }

  /// 「100kg×8」「+10kg×8」「自重×8」「アシスト14kg×8」
  String setLabel(String exerciseId, SetEntry s) {
    final w = s.weight;
    final r = s.reps ?? 0;
    switch (loadTypeOf(exerciseId)) {
      case loadBodyweight:
        return (w == null || w == 0) ? '自重×$r' : '+${fmtNum(w)}kg×$r';
      case loadAssisted:
        return 'アシスト${fmtNum(w ?? 0)}kg×$r';
      case loadRepsOnly:
        return '$r回';
      default:
        return '${fmtNum(w ?? 0)}kg×$r';
    }
  }

  int totalReps(Iterable<SetEntry> sets) =>
      sets.fold(0, (a, s) => a + (s.reps ?? 0));

  // ---------- 体重 ----------

  void setBodyWeight(String date, double kg) {
    bodyWeights.removeWhere((b) => b.date == date);
    bodyWeights.add(BodyWeight(date: date, kg: kg));
    bodyWeights.sort((a, b) => a.date.compareTo(b.date));
    changed();
  }

  void deleteBodyWeight(String date) {
    bodyWeights.removeWhere((b) => b.date == date);
    changed();
  }

  // ---------- バックアップ ----------

  String exportJson() => const JsonEncoder.withIndent(' ').convert(toJson());

  /// 失敗したら例外を投げ、今のデータはそのまま残す。
  void importJson(String text) {
    final j = Map<String, dynamic>.from(jsonDecode(text) as Map);
    if (j['exercises'] == null || j['menus'] == null) {
      throw const FormatException('このアプリのバックアップではありません');
    }
    _fromJson(j);
    changed();
  }

  String exportCsv() {
    final b = StringBuffer('日付,メニュー,種目,セット,入力重量(kg),回数,実負荷(kg)\n');
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    for (final w in workouts) {
      final menuName = menu(w.menuId)?.name ?? '';
      for (final l in w.logs) {
        final name = exercise(l.exerciseId)?.name ?? '削除した種目';
        var n = 0;
        for (final s in l.doneSets) {
          n++;
          b.writeln([
            w.date,
            q(menuName),
            q(name),
            n,
            fmtNum(s.weight ?? 0),
            s.reps ?? 0,
            fmt1(loadOf(l.exerciseId, s, w.date) ?? 0),
          ].join(','));
        }
      }
    }
    return b.toString();
  }
}
