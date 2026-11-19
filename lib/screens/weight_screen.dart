// 体重の記録とグラフ。

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  DateTime date = DateTime.now();
  final input = TextEditingController();

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(input.text.replaceAll(',', '.'));
    if (v == null || v <= 0) return;
    store.setBodyWeight(fmtDate(date), v);
    input.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => date = d);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final theme = Theme.of(context);
        final list = store.bodyWeights;
        final recent =
            list.length > 90 ? list.sublist(list.length - 90) : list;
        return Scaffold(
          appBar: AppBar(title: const Text('体重')),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    OutlinedButton(
                      onPressed: _pickDate,
                      child: Text(shortDate(fmtDate(date))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: input,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            hintText: '65.0', suffixText: 'kg', isDense: true),
                        onSubmitted: (_) => _save(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(onPressed: _save, child: const Text('記録')),
                  ]),
                ),
              ),
              if (recent.length >= 2)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                    child: SizedBox(
                      height: 200,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _WeightChart(
                          recent,
                          line: theme.colorScheme.primary,
                          grid: theme.colorScheme.outlineVariant,
                          text: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('まだ記録がありません', textAlign: TextAlign.center),
                ),
              for (var i = list.length - 1; i >= 0; i--)
                Dismissible(
                  key: ValueKey(list[i].date),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    color: theme.colorScheme.errorContainer,
                    child: const Icon(Icons.delete_outline),
                  ),
                  onDismissed: (_) => store.deleteBodyWeight(list[i].date),
                  child: ListTile(
                    dense: true,
                    title: Text('${fmtNum(list[i].kg)} kg'),
                    subtitle: Text(shortDate(list[i].date)),
                    trailing: i == 0
                        ? null
                        : Text(_diff(list[i].kg - list[i - 1].kg)),
                  ),
                ),
              if (list.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('左にスワイプで削除',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center),
                ),
            ],
          ),
        );
      },
    );
  }

  String _diff(double d) {
    final r = (d * 10).round() / 10;
    if (r == 0) return '±0';
    return r > 0 ? '+${fmtNum(r)}' : fmtNum(r);
  }
}

class _WeightChart extends CustomPainter {
  _WeightChart(this.data,
      {required this.line, required this.grid, required this.text});

  final List<BodyWeight> data;
  final Color line;
  final Color grid;
  final Color text;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 40.0;
    const bottom = 20.0;
    final w = size.width - left;
    final h = size.height - bottom;

    var minY = data.map((e) => e.kg).reduce((a, b) => a < b ? a : b);
    var maxY = data.map((e) => e.kg).reduce((a, b) => a > b ? a : b);
    minY = (minY - 0.5).floorToDouble();
    maxY = (maxY + 0.5).ceilToDouble();

    final first = DateTime.parse(data.first.date);
    final days = DateTime.parse(data.last.date).difference(first).inDays;
    final span = days == 0 ? 1 : days;

    Offset pt(BodyWeight b) {
      final x = left +
          w * DateTime.parse(b.date).difference(first).inDays / span;
      final y = h - h * (b.kg - minY) / (maxY - minY);
      return Offset(x, y);
    }

    void label(String s, Offset at, {bool right = false}) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: text, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(right ? tp.width : 0, tp.height / 2));
    }

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final v = minY + (maxY - minY) * k / 4;
      final y = h - h * k / 4;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), gridPaint);
      label(fmtNum((v * 10).round() / 10), Offset(left - 4, y), right: true);
    }
    label(shortDate(data.first.date), Offset(left, h + 10));
    label(shortDate(data.last.date), Offset(size.width, h + 10), right: true);

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final p = pt(data[i]);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final dot = Paint()..color = line;
    for (final b in data) {
      canvas.drawCircle(pt(b), 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChart old) => true;
}
