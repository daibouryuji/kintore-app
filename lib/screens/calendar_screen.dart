// トレーニングした日に赤丸が付く月カレンダー。
// 日付をタップすると、その日を選んで前の画面に戻る。

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.selected});

  final DateTime selected;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime month =
      DateTime(widget.selected.year, widget.selected.month);

  void _move(int months) =>
      setState(() => month = DateTime(month.year, month.month + months));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // トレーニングした日（記録のあるセットが1つ以上ある日）→ メニュー名
    final trained = <String, String>{};
    for (final w in store.workouts) {
      if (w.hasDone) trained[w.date] = store.menu(w.menuId)?.name ?? '自由';
    }

    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // 月曜始まり
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();
    final todayKey = fmtDate(DateTime.now());
    final selectedKey = fmtDate(widget.selected);
    final monthCount = trained.keys
        .where((d) => d.startsWith(
            '${month.year}-${month.month.toString().padLeft(2, '0')}-'))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text('${month.year}年${month.month}月'),
        actions: [
          IconButton(
              onPressed: () => _move(-1),
              icon: const Icon(Icons.chevron_left)),
          IconButton(
              onPressed: () => _move(1),
              icon: const Icon(Icons.chevron_right)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            for (final (i, l) in weekdayLabels.indexed)
              Expanded(
                child: Center(
                  child: Text(l,
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: i == 5
                              ? Colors.blue
                              : i == 6
                                  ? Colors.red
                                  : null)),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          for (var r = 0; r < rows; r++)
            Row(children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: () {
                    final day = r * 7 + c - leading + 1;
                    if (day < 1 || day > daysInMonth) {
                      return const SizedBox(height: 64);
                    }
                    final date = DateTime(month.year, month.month, day);
                    final key = fmtDate(date);
                    return _DayCell(
                      day: day,
                      menuName: trained[key],
                      isToday: key == todayKey,
                      isSelected: key == selectedKey,
                      onTap: () => Navigator.pop(context, date),
                    );
                  }(),
                ),
            ]),
          const SizedBox(height: 16),
          Center(
            child: Text('この月のトレーニング：$monthCount日',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('日付をタップすると、その日の記録を開きます',
                style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.menuName,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final String? menuName;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trained = menuName != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 64,
        decoration: isSelected
            ? BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: trained ? Colors.red : null,
                border: isToday && !trained
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
              child: Text(
                '$day',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: trained ? Colors.white : null,
                  fontWeight:
                      trained || isToday ? FontWeight.bold : null,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              menuName ?? '',
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
