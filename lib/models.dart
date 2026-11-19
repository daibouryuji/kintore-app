// データの型と、日付まわりの小さな関数。

int _idCounter = 0;
String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

String _two(int n) => n.toString().padLeft(2, '0');

/// 2026-11-19 の形式
String fmtDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

const weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

/// 11/19(木) の形式
String shortDate(String date) {
  final d = DateTime.parse(date);
  return '${d.month}/${d.day}(${weekdayLabels[d.weekday - 1]})';
}

/// 60.0 → "60", 62.5 → "62.5"
String fmtNum(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

const bodyParts = ['胸', '背中', '肩', '腕', '脚', '腹', 'その他'];

/// 負荷の種類
const loadNormal = 'normal'; // 入力した重量がそのまま負荷
const loadBodyweight = 'bodyweight'; // 体重 ＋ 加重
const loadAssisted = 'assisted'; // 体重 − アシスト
const loadRepsOnly = 'reps'; // 回数だけ記録（腹筋など）
const loadTypeLabels = {
  loadNormal: '通常（入力した重量）',
  loadBodyweight: '自重（体重＋加重）',
  loadAssisted: 'アシスト（体重−アシスト）',
  loadRepsOnly: '回数のみ（腹筋など）',
};

/// 推定1RM（Epley式：負荷 ×（1 + 回数 / 30））。1回ならその負荷。
double? e1rmOf(double? load, int? reps) {
  if (load == null || reps == null || load <= 0 || reps <= 0) return null;
  return reps == 1 ? load : load * (1 + reps / 30);
}

class Exercise {
  final String id;
  String name;
  String bodyPart;
  String memo;
  String loadType;

  Exercise({
    required this.id,
    required this.name,
    this.bodyPart = 'その他',
    this.memo = '',
    this.loadType = loadNormal,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'bodyPart': bodyPart,
        'memo': memo,
        'loadType': loadType,
      };

  factory Exercise.fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String;
    var type = j['loadType'] as String?;
    // 古いデータは、名前から自重・アシスト種目を推測する
    type ??= name.contains('アシスト')
        ? loadAssisted
        : (name == '懸垂' || name == 'ディップス' || name.contains('チンニング'))
            ? loadBodyweight
            : (name.contains('アブローラー') || name.contains('腹筋'))
                ? loadRepsOnly
                : loadNormal;
    return Exercise(
      id: j['id'] as String,
      name: name,
      bodyPart: (j['bodyPart'] as String?) ?? 'その他',
      memo: (j['memo'] as String?) ?? '',
      loadType: type,
    );
  }
}

/// メニューに入っている1種目（目標セット数・回数つき）
class MenuItem {
  String exerciseId;
  int sets;
  String reps;

  MenuItem({required this.exerciseId, this.sets = 3, this.reps = '8〜10'});

  Map<String, dynamic> toJson() =>
      {'exerciseId': exerciseId, 'sets': sets, 'reps': reps};

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        exerciseId: j['exerciseId'] as String,
        sets: (j['sets'] as num?)?.toInt() ?? 3,
        reps: (j['reps'] as String?) ?? '',
      );
}

/// プッシュ・プルなどの名前付きメニュー
class Menu {
  final String id;
  String name;

  /// 基本の曜日。1=月 … 7=日、null=曜日なし
  int? weekday;
  List<MenuItem> items;

  Menu({
    required this.id,
    required this.name,
    this.weekday,
    List<MenuItem>? items,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'weekday': weekday,
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory Menu.fromJson(Map<String, dynamic> j) => Menu(
        id: j['id'] as String,
        name: j['name'] as String,
        weekday: (j['weekday'] as num?)?.toInt(),
        items: ((j['items'] as List?) ?? [])
            .map((e) => MenuItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class SetEntry {
  final String id;
  double? weight;
  int? reps;

  SetEntry({required this.id, this.weight, this.reps});

  /// 回数が入っていれば「やったセット」（自重種目は重量が空でもよい）
  bool get done => reps != null && reps! > 0;

  Map<String, dynamic> toJson() => {'id': id, 'weight': weight, 'reps': reps};

  factory SetEntry.fromJson(Map<String, dynamic> j) => SetEntry(
        id: (j['id'] as String?) ?? newId(),
        weight: (j['weight'] as num?)?.toDouble(),
        reps: (j['reps'] as num?)?.toInt(),
      );

}

/// 小数1桁に丸めて表示（100.0 → "100", 103.33 → "103.3"）
String fmt1(double v) => fmtNum((v * 10).round() / 10);

class ExerciseLog {
  final String exerciseId;
  List<SetEntry> sets;

  ExerciseLog({required this.exerciseId, List<SetEntry>? sets})
      : sets = sets ?? [];

  List<SetEntry> get doneSets => sets.where((s) => s.done).toList();

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'sets': sets.map((e) => e.toJson()).toList(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        exerciseId: j['exerciseId'] as String,
        sets: ((j['sets'] as List?) ?? [])
            .map((e) => SetEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// 1日分のトレーニング
class Workout {
  final String id;
  final String date;
  String? menuId;
  List<ExerciseLog> logs;

  Workout({
    required this.id,
    required this.date,
    this.menuId,
    List<ExerciseLog>? logs,
  }) : logs = logs ?? [];

  bool get hasDone => logs.any((l) => l.sets.any((s) => s.done));

  int get doneSetCount => logs.fold(0, (a, l) => a + l.doneSets.length);
  int get setCount => logs.fold(0, (a, l) => a + l.sets.length);

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'menuId': menuId,
        'logs': logs.map((e) => e.toJson()).toList(),
      };

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
        id: j['id'] as String,
        date: j['date'] as String,
        menuId: j['menuId'] as String?,
        logs: ((j['logs'] as List?) ?? [])
            .map((e) =>
                ExerciseLog.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class BodyWeight {
  final String date;
  double kg;

  BodyWeight({required this.date, required this.kg});

  Map<String, dynamic> toJson() => {'date': date, 'kg': kg};

  factory BodyWeight.fromJson(Map<String, dynamic> j) => BodyWeight(
        date: j['date'] as String,
        kg: (j['kg'] as num).toDouble(),
      );
}
