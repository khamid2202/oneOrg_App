import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'class_insights.dart';

// The web's `TrendPanel` for one class (My Class → Grades): the class's daily
// scores by week or month, a chart of the class and one picked student, and
// every student and subject with a sparkline and its change, falling first,
// so regress stands out.

const _tabular = [FontFeature.tabularFigures()];

/// Below this many points either way, a change reads as steady.
const _steady = 1.0;

const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _amber = Color(0xFFD97706);
const _studentLine = Color(0xFF2563EB);

String _fmt(double? value) => value == null
    ? '—'
    : value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

Color _scoreTone(double? value, Color muted) => value == null
    ? muted
    : value < 60
    ? _red
    : value < 75
    ? _amber
    : _green;

Color _changeTone(double? change, Color muted) =>
    change == null || change.abs() < _steady
    ? muted
    : change > 0
    ? _green
    : _red;

class GradeTrendPanel extends StatefulWidget {
  const GradeTrendPanel({
    super.key,
    required this.loadTrend,
    required this.className,
  });

  final Future<GradeTrend> Function(String bucket, int? subjectId) loadTrend;
  final String className;

  @override
  State<GradeTrendPanel> createState() => _GradeTrendPanelState();
}

class _GradeTrendPanelState extends State<GradeTrendPanel> {
  final _cache = <String, GradeTrend>{};
  String _bucket = 'week';
  int? _subjectId;
  GradeTrend? _trend;
  bool _loading = false;
  bool _failed = false;

  /// Subjects to filter by: every one the trend has shown unfiltered.
  final _subjectOptions = <int, String>{};
  bool _showSubjects = false;
  bool _rising = false;
  int? _studentId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bucket = _bucket, subjectId = _subjectId;
    final key = '$bucket:$subjectId';
    setState(() {
      _trend = _cache[key];
      _loading = true;
      _failed = false;
    });
    try {
      final trend = await widget.loadTrend(bucket, subjectId);
      _cache[key] = trend;
      if (!mounted || bucket != _bucket || subjectId != _subjectId) return;
      setState(() {
        _trend = trend;
        _loading = false;
        if (subjectId == null) {
          for (final s in trend.subjects) {
            _subjectOptions[s.id] = s.name;
          }
        }
      });
    } catch (_) {
      if (!mounted || bucket != _bucket || subjectId != _subjectId) return;
      setState(() {
        _loading = false;
        _failed = _trend == null;
      });
    }
  }

  void _setBucket(String bucket) {
    if (bucket == _bucket) return;
    _bucket = bucket;
    _load();
  }

  void _setSubject(int? subjectId) {
    if (subjectId == _subjectId) return;
    _subjectId = subjectId;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final trend = _trend;
    // Nothing to show until the class has daily scores, unless a subject
    // filter is on (so it can be turned off again).
    if (trend == null && !_failed && _subjectId == null) {
      return const SizedBox.shrink();
    }
    if (trend != null && trend.overall.gradeCount == 0 && _subjectId == null) {
      return const SizedBox.shrink();
    }

    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final muted = colors.mutedText;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  widget.className,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: 8),
                Text(
                  _fmt(trend.overall.average),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _scoreTone(trend.overall.average, muted),
                    fontFeatures: _tabular,
                  ),
                ),
                const SizedBox(width: 6),
                _Change(trend.overall.change),
              ],
              if (_loading) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _subjectPicker(l, colors)),
              const SizedBox(width: 8),
              _Segments(
                items: [('week', l.trendWeek), ('month', l.trendMonth)],
                value: _bucket,
                onChanged: _setBucket,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_failed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(l.trendFailed, style: TextStyle(color: muted)),
              ),
            )
          else if (trend == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            ..._content(l, colors, trend),
        ],
      ),
    );
  }

  Widget _subjectPicker(AppLocalizations l, AppColors colors) {
    final options = _subjectOptions.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _subjectId,
          isExpanded: true,
          isDense: true,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          items: [
            DropdownMenuItem(value: null, child: Text(l.trendAllSubjects)),
            for (final option in options)
              DropdownMenuItem(
                value: option.key,
                child: Text(option.value, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _setSubject,
        ),
      ),
    );
  }

  List<Widget> _content(
    AppLocalizations l,
    AppColors colors,
    GradeTrend trend,
  ) {
    final muted = colors.mutedText;
    // Leading weeks/months without scores (the year's first days) are left
    // out.
    final from = math.max(0, trend.overall.values.indexWhere((v) => v != null));
    final student = trend.rows.where((r) => r.id == _studentId).firstOrNull;
    final locale = Localizations.localeOf(context).toString();
    final labels = [
      for (final key in trend.buckets.skip(from))
        switch (DateTime.tryParse(key)) {
          final date? => DateFormat(
            trend.bucket == 'week' ? 'd MMM' : 'MMM',
            locale,
          ).format(date),
          null => key,
        },
    ];

    final items = [...(_showSubjects ? trend.subjects : trend.rows)]
      ..sort((a, b) {
        if (a.change == null) {
          return b.change == null ? a.name.compareTo(b.name) : 1;
        }
        if (b.change == null) return -1;
        final byChange = a.change!.compareTo(b.change!);
        return _rising ? -byChange : byChange;
      });
    final subjectNames = {for (final s in trend.subjects) s.id: s.name};

    return [
      SizedBox(
        height: 170,
        child: CustomPaint(
          painter: _ChartPainter(
            overall: trend.overall.values.skip(from).toList(),
            student: student?.values.skip(from).toList(),
            labels: labels,
            overallColor: muted,
            gridColor: colors.line,
            textColor: muted,
          ),
        ),
      ),
      if (student != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              _Legend(color: muted, label: widget.className),
              const SizedBox(width: 12),
              Flexible(
                child: _Legend(color: _studentLine, label: student.name),
              ),
            ],
          ),
        ),
      const SizedBox(height: 10),
      Row(
        children: [
          _Segments(
            items: [('rows', l.trendStudents), ('subjects', l.trendSubjects)],
            value: _showSubjects ? 'subjects' : 'rows',
            onChanged: (v) => setState(() => _showSubjects = v == 'subjects'),
          ),
          const Spacer(),
          Tooltip(
            message: _rising ? l.trendRisingFirst : l.trendFallingFirst,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _rising = !_rising),
              icon: Icon(
                _rising
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 18,
                color: _rising ? _green : _red,
              ),
            ),
          ),
        ],
      ),
      if (items.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text('—', style: TextStyle(color: muted)),
          ),
        )
      else
        for (final item in items) ...[
          InkWell(
            onTap: () => _showSubjects
                ? _setSubject(item.id)
                : setState(
                    () => _studentId = _studentId == item.id ? null : item.id,
                  ),
            child: Container(
              color: !_showSubjects && item.id == _studentId
                  ? colors.softBg
                  : null,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    height: 18,
                    child: CustomPaint(
                      painter: _SparklinePainter(
                        item.values.skip(from).toList(),
                        _changeTone(item.change, muted),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      _fmt(item.average),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _scoreTone(item.average, muted),
                        fontFeatures: _tabular,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _Change(item.change),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_showSubjects && item.id == _studentId)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final s in [
                    ...item.subjects,
                  ]..sort((a, b) => (a.change ?? 0).compareTo(b.change ?? 0)))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.line),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            subjectNames[s.id] ?? '',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _fmt(s.average),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _scoreTone(s.average, muted),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _Change(s.change, fontSize: 11),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
    ];
  }
}

/// ▲ / ▼ with the change in points over the window.
class _Change extends StatelessWidget {
  const _Change(this.value, {this.fontSize = 12});

  final double? value;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final muted = appColorsOf(context).mutedText;
    final value = this.value;
    final color = _changeTone(value, muted);
    if (value == null) {
      return Text(
        '—',
        style: TextStyle(fontSize: fontSize, color: muted),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value.abs() >= _steady)
          Icon(
            value > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: fontSize + 1,
            color: color,
          ),
        Text(
          '${value > 0 ? '+' : ''}${_fmt(value)}',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: color,
            fontFeatures: _tabular,
          ),
        ),
      ],
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<(String, String)> items;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.line.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (id, label) in items)
            GestureDetector(
              onTap: () => onChanged(id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: id == value ? colors.card : null,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: id == value ? null : colors.mutedText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 12, height: 3, color: color),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
      ),
    ],
  );
}

/// Polylines through [values] mapped by [x] and [y]; nulls break the line and
/// a lone value is a dot.
void _drawSeries(
  Canvas canvas,
  List<double?> values,
  double Function(int i) x,
  double Function(double v) y,
  Paint paint, {
  double dot = 1.5,
}) {
  var path = <Offset>[];
  void flush() {
    if (path.length == 1) {
      canvas.drawCircle(path.first, dot, Paint()..color = paint.color);
    } else if (path.length > 1) {
      canvas.drawPath(
        Path()..addPolygon(path, false),
        paint..style = PaintingStyle.stroke,
      );
    }
    path = [];
  }

  for (var i = 0; i < values.length; i++) {
    final v = values[i];
    if (v == null) {
      flush();
    } else {
      path.add(Offset(x(i), y(v)));
    }
  }
  flush();
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.overall,
    required this.student,
    required this.labels,
    required this.overallColor,
    required this.gridColor,
    required this.textColor,
  });

  final List<double?> overall;
  final List<double?>? student;
  final List<String> labels;
  final Color overallColor;
  final Color gridColor;
  final Color textColor;

  TextPainter _text(String text) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: 10, color: textColor),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final present = [...overall, ...?student].whereType<double>().toList();
    if (present.isEmpty || overall.isEmpty) return;
    // Like the web: 5 points of room either side, on multiples of 5, 0–100.
    final low = math.max(0, ((present.reduce(math.min) - 5) / 5).floor() * 5);
    final high = math.min(100, ((present.reduce(math.max) + 5) / 5).ceil() * 5);
    final span = math.max(1, high - low);

    const left = 28.0, bottom = 16.0, top = 6.0, right = 6.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;
    final count = overall.length;
    double x(int i) =>
        left + (count == 1 ? width / 2 : width * i / (count - 1));
    double y(double v) => top + height * (1 - (v - low) / span);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var k = 0; k <= 4; k++) {
      final v = low + span * k / 4;
      final yy = y(v.toDouble());
      canvas.drawLine(Offset(left, yy), Offset(size.width - right, yy), grid);
      final t = _text(v.round().toString());
      t.paint(canvas, Offset(left - t.width - 4, yy - t.height / 2));
    }
    // First, middle and last bucket labels.
    for (final i in {0, count ~/ 2, count - 1}) {
      if (i < 0 || i >= labels.length) continue;
      final t = _text(labels[i]);
      final dx = (x(i) - t.width / 2).clamp(left, size.width - t.width);
      t.paint(canvas, Offset(dx, size.height - t.height));
    }

    _drawSeries(
      canvas,
      overall,
      x,
      y,
      Paint()
        ..color = overallColor
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    if (student != null) {
      _drawSeries(
        canvas,
        student!,
        x,
        y,
        Paint()
          ..color = _studentLine
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
        dot: 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.overall != overall ||
      old.student != student ||
      old.labels != labels ||
      old.overallColor != overallColor;
}

/// A tiny line of scores, scaled to its own values but at least 20 points
/// tall so a drop shows; a dot marks the latest.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);

  final List<double?> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final present = values.whereType<double>().toList();
    if (values.length < 2 || present.isEmpty) return;
    final lo = present.reduce(math.min), hi = present.reduce(math.max);
    final mid = (lo + hi) / 2;
    final span = math.max(20, hi - lo);
    final step = size.width / (values.length - 1);
    double x(int i) => i * step;
    double y(double v) =>
        size.height - 2 - ((v - (mid - span / 2)) / span) * (size.height - 4);
    _drawSeries(
      canvas,
      values,
      x,
      y,
      Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
    final last = values.lastIndexWhere((v) => v != null);
    if (last >= 0) {
      canvas.drawCircle(
        Offset(x(last), y(values[last]!)),
        2,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}
