import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../shared/api_client.dart';

// The web's `dombitPdf.js`: last week's Dombit dollars for a homeroom class.
// Students appear by DIS number only (no student or teacher names) with the
// balance and the week's grades / behaviour / spending, then every negative
// behaviour mark of the week with what it cost. Labels stay in English, like
// the web's PDF.

const _ink = PdfColor.fromInt(0xFF1E293B);
const _muted = PdfColor.fromInt(0xFF64748B);
const _red = PdfColor.fromInt(0xFFBE123C);
const _green = PdfColor.fromInt(0xFF047857);
const _line = PdfColor.fromInt(0xFFCBD5E1);
const _stripe = PdfColor.fromInt(0xFFF8F9FB);
const _amber = PdfColor.fromInt(0xFFD97706);
const _redWash = PdfColor.fromInt(0xFFFEF2F2);

/// [key, header, width in pt]; DIS takes the rest.
const _columns = [
  ('balance', 'Balance', 58.0),
  ('grades', 'Grades', 52.0),
  ('behavior_plus', 'Behaviour +', 62.0),
  ('behavior_minus', 'Behaviour −', 62.0),
  ('spent', 'Spent', 50.0),
  ('change', 'Week', 52.0),
];

/// "2026-11-09" → "09.11".
String _dm(String iso) =>
    iso.length >= 10 ? '${iso.substring(8, 10)}.${iso.substring(5, 7)}' : iso;

/// Dollars as the web writes them: "$12", "−$3.50", "+$2" with [sign], and
/// nothing for a signed zero.
String dombitMoney(num? n, {bool sign = false}) {
  if (n == null || n == 0) return sign ? '' : r'$0';
  final abs = n.abs();
  final text = abs == abs.roundToDouble()
      ? abs.toInt().toString()
      : abs.toStringAsFixed(2);
  return '${n < 0
      ? '−'
      : sign
      ? '+'
      : ''}\$$text';
}

PdfColor _tone(num n) => n < 0
    ? _red
    : n > 0
    ? _green
    : _muted;

/// Builds the PDF from `/cashier/class-report/:groupId`.
Future<Uint8List> buildDombitPdf(
  Map<String, dynamic> r, {
  required pw.Font regular,
  required pw.Font bold,
  String? logoSvg,
}) {
  final className = asStr(r['class_name']) ?? '';
  final from = asStr(r['from']) ?? '';
  final to = asStr(r['to']) ?? '';
  final students = [
    for (final s in (r['students'] as List? ?? const []))
      if (s is Map) Map<String, dynamic>.from(s),
  ];
  final negatives = [
    for (final n in (r['negatives'] as List? ?? const []))
      if (n is Map) Map<String, dynamic>.from(n),
  ];

  pw.TextStyle style(bool isBold, double size, [PdfColor color = _ink]) =>
      pw.TextStyle(font: isBold ? bold : regular, fontSize: size, color: color);

  // Negative behaviour by student, the biggest deductions first.
  final codes = {
    for (final s in students) '${s['person_id']}': asStr(s['code']) ?? '?',
  };
  final byStudent = <String, List<Map<String, dynamic>>>{};
  for (final n in negatives) {
    byStudent.putIfAbsent('${n['person_id']}', () => []).add(n);
  }
  final groups =
      [
        for (final e in byStudent.entries)
          (
            name: codes[e.key] ?? '?',
            list: e.value,
            total: e.value.fold<double>(
              0,
              (a, n) => a + (asDouble(n['dollars']) ?? 0),
            ),
          ),
      ]..sort((a, b) {
        final byTotal = a.total.compareTo(b.total);
        return byTotal != 0 ? byTotal : a.name.compareTo(b.name);
      });
  final negativeTotal = groups.fold<double>(0, (a, g) => a + g.total);

  pw.Widget cell(String text, pw.TextStyle st, {bool center = true}) =>
      pw.Container(
        height: 16,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
        child: pw.Text(text, style: st),
      );

  final headStyle = style(true, 7.5, PdfColors.white);
  final table = pw.Table(
    columnWidths: {
      0: const pw.FixedColumnWidth(22),
      1: const pw.FlexColumnWidth(),
      for (var i = 0; i < _columns.length; i++)
        i + 2: pw.FixedColumnWidth(_columns[i].$3),
    },
    border: const pw.TableBorder(bottom: pw.BorderSide(color: _line)),
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _amber),
        children: [
          cell('#', headStyle),
          cell('DIS', headStyle, center: false),
          for (final c in _columns) cell(c.$2, headStyle),
        ],
      ),
      for (var i = 0; i < students.length; i++)
        pw.TableRow(
          decoration: i.isOdd ? const pw.BoxDecoration(color: _stripe) : null,
          children: [
            cell('${i + 1}', style(false, 8, _muted)),
            cell(
              asStr(students[i]['code']) ?? '—',
              style(false, 8.5),
              center: false,
            ),
            for (final c in _columns)
              () {
                final v = asDouble(students[i][c.$1]) ?? 0;
                final isBalance = c.$1 == 'balance';
                return cell(
                  dombitMoney(v, sign: !isBalance),
                  style(
                    isBalance || c.$1 == 'change',
                    8.5,
                    isBalance ? (v < 0 ? _red : _ink) : _tone(v),
                  ),
                );
              }(),
          ],
        ),
    ],
  );

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$className · ${_dm(from)}–${_dm(to)}',
            style: style(false, 7, _muted),
          ),
          pw.Text(
            '${context.pageNumber}/${context.pagesCount}',
            style: style(false, 7, _muted),
          ),
        ],
      ),
      build: (context) => [
        pw.Row(
          children: [
            if (logoSvg != null) ...[
              pw.SvgImage(svg: logoSvg, height: 30),
              pw.SizedBox(width: 10),
            ],
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Dombit \$ · $className', style: style(true, 15)),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${_dm(from)}–${_dm(to)}.${to.length >= 4 ? to.substring(0, 4) : ''}',
                  style: style(false, 9.5, _muted),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        table,
        pw.SizedBox(height: 22),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Behaviour −', style: style(true, 12)),
            pw.Text(dombitMoney(negativeTotal), style: style(true, 12, _red)),
          ],
        ),
        pw.SizedBox(height: 6),
        if (groups.isEmpty) pw.Text('—', style: style(false, 9, _muted)),
        for (final g in groups) ...[
          pw.SizedBox(height: 6),
          pw.Container(
            color: _redWash,
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(g.name, style: style(true, 9.5)),
                pw.Text(dombitMoney(g.total), style: style(true, 9.5, _red)),
              ],
            ),
          ),
          for (final n in g.list)
            pw.Container(
              padding: const pw.EdgeInsets.fromLTRB(4, 4, 4, 4),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _line)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 36,
                    child: pw.Text(
                      _dm(asStr(n['date']) ?? ''),
                      style: style(false, 8, _muted),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          asStr(n['reason']) ?? '—',
                          style: style(false, 8.5),
                        ),
                        if ((asStr(n['comment']) ?? '').isNotEmpty)
                          pw.Text(
                            '“${asStr(n['comment'])}”',
                            style: style(false, 8),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    dombitMoney(asDouble(n['dollars'])),
                    style: style(true, 8.5, _red),
                  ),
                ],
              ),
            ),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Fetches last week's report for [groupId], builds the PDF and hands it to
/// the phone's share sheet.
Future<void> shareDombitPdf(ApiClient api, int groupId) async {
  final results = await Future.wait([
    api.get('/cashier/class-report/$groupId'),
    rootBundle.load('assets/pdf/DejaVuSans.ttf'),
    rootBundle.load('assets/pdf/DejaVuSans-Bold.ttf'),
    rootBundle.loadString('assets/pdf/logo.svg'),
  ]);
  final report = ApiClient.one(results[0]);
  final bytes = await buildDombitPdf(
    report,
    regular: pw.Font.ttf(results[1] as ByteData),
    bold: pw.Font.ttf(results[2] as ByteData),
    logoSvg: results[3] as String,
  );
  final name =
      'Dombit ${asStr(report['class_name']) ?? ''} '
      '${asStr(report['from']) ?? ''}.pdf';
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: name)],
      fileNameOverrides: [name],
      subject: name,
    ),
  );
}
