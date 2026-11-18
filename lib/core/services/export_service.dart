import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import '../theme/format.dart';
import 'gradebook.dart';

/// CSV of every score and a one-page PDF grade report per term.
class ExportService {
  const ExportService._();

  static String scoresCsv(Gradebook gb) {
    final rows = <List<Object?>>[
      [
        'School year',
        'Term',
        'Subject code',
        'Subject title',
        'Units',
        'Component',
        'Weight %',
        'Item',
        'Score',
        'Total',
        'Percent',
        'Date',
        'Status',
        'Note',
      ],
    ];
    final terms = {for (final t in gb.terms) t.id: t};
    for (final s in gb.subjects.sortedBy(
      (s) => '${terms[s.termId]?.order ?? 0}${s.code}',
    )) {
      final t = terms[s.termId];
      for (final c in gb.componentsOf(s.id!)) {
        for (final sc in gb.scoresOfComponent(c.id!).sortedBy((x) => x.date)) {
          rows.add([
            t?.schoolYear,
            t?.kind.label,
            s.code,
            s.title,
            s.units,
            c.name,
            c.weight,
            sc.title,
            sc.score,
            sc.total,
            sc.percent?.toStringAsFixed(2),
            dateOnly(sc.date),
            sc.isUpcoming ? 'Upcoming' : 'Graded',
            sc.note,
          ]);
        }
      }
    }
    return csv.encode(rows);
  }

  static Future<Uint8List> termReportPdf(Gradebook gb, Term term) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/SchibstedGrotesk-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/SchibstedGrotesk-Bold.ttf'),
    );
    final monoF = pw.Font.ttf(
      await rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'),
    );
    final monoB = pw.Font.ttf(
      await rootBundle.load('assets/fonts/JetBrainsMono-Bold.ttf'),
    );
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/brand/lcc_logo_512.png')).buffer
          .asUint8List(),
    );

    final p = gb.profile;
    final results = gb.resultsIn(term.id)
      ..sort((a, b) => a.subject.code.compareTo(b.subject.code));
    final gwa = gb.termGwa(term.id!);
    const ink = PdfColor.fromInt(0xFF14171C);
    const muted = PdfColor.fromInt(0xFF5E6672);
    const line = PdfColor.fromInt(0xFFE3E1DA);
    const blue = PdfColor.fromInt(0xFF2B3BE0);

    pw.TextStyle t(
      double size, {
      bool b = false,
      bool m = false,
      PdfColor color = ink,
    }) => pw.TextStyle(
      font: m ? (b ? monoB : monoF) : (b ? bold : regular),
      fontSize: size,
      color: color,
    );

    final doc = pw.Document(
      title: 'Grade report ${term.shortLabel}',
      author: p?.name ?? 'LCC GradeTrack',
    );
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Image(logo, width: 46, height: 46),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Legacy College of Compostela',
                        style: t(13, b: true),
                      ),
                      pw.Text(
                        'Grade report · ${term.longLabel}',
                        style: t(10, color: muted),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('GWA', style: t(9, color: muted)),
                    pw.Text(
                      fmtGrade(gwa.gwa),
                      style: t(24, b: true, m: true, color: blue),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.Container(height: 1, color: line),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(p?.name ?? '', style: t(11, b: true)),
                ),
                pw.Text(
                  [
                    if (p?.studentNo.isNotEmpty ?? false) p!.studentNo,
                    if (p?.program.isNotEmpty ?? false)
                      '${p!.program} ${p.yearLevel}',
                  ].join(' · '),
                  style: t(10, color: muted),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: [
                'Code',
                'Descriptive title',
                'Units',
                'Percent',
                'Grade',
              ],
              data: [
                for (final r in results)
                  [
                    r.subject.code,
                    r.subject.title,
                    fmtNum(r.subject.units),
                    r.isFinal ? 'final' : fmtPct(r.percent),
                    r.mark?.code ?? fmtGrade(r.equivalent),
                  ],
              ],
              headerStyle: t(9, b: true, color: muted),
              cellStyle: t(10),
              headerDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: line)),
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: line, width: 0.5),
                ),
              ),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              columnWidths: {
                0: const pw.FixedColumnWidth(60),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(40),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FixedColumnWidth(44),
              },
              cellPadding: const pw.EdgeInsets.symmetric(
                vertical: 6,
                horizontal: 4,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Units counted: ${fmtNum(gwa.units)}   GWA = Σ(units × grade) ÷ Σ units = ${fmtGrade(gwa.gwa)}',
                  style: t(9, m: true, color: muted),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Text(
              'Generated by LCC GradeTrack on ${fmtMdy(DateTime.now())}. Computed from scores entered by the student; not an official record.',
              style: t(8, color: muted),
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
