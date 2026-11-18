import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:lcc_gradetrack/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:lcc_gradetrack/core/theme/icons.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/seed_sample.dart';
import '../../core/providers/providers.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/export_service.dart';
import '../../core/services/repository.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/primitives.dart';

class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() op) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await op();
    } on DataException catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } on Object catch (e) {
      if (mounted) showToast(context, 'Something went wrong: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _stamp {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}';
  }

  Future<File> _temp(String name, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, name));
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  Future<void> _exportBackup() => _run(() async {
    final json = await BackupService(ref.read(repoProvider).db).exportJson();
    final f = await _temp('gradetrack-backup-$_stamp.json', utf8.encode(json));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path, mimeType: 'application/json')],
        title: 'GradeTrack backup',
      ),
    );
  });

  Future<void> _import() => _run(() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isEmpty || files.first.path == null) return;
    final text = await File(files.first.path!).readAsString();
    final parsed = BackupService.parse(text);
    final subjects = parsed['subjects']!.length;
    final scores = parsed['scores']!.length;
    if (!mounted) return;
    final ok = await confirmAction(
      context,
      title: 'Replace all data?',
      body:
          'The backup has ${parsed['terms']!.length} terms, $subjects subjects and $scores scores. Everything on this phone will be replaced. The PIN is not part of backups.',
      confirm: 'Replace',
    );
    if (!ok) return;
    await ref
        .read(gradebookProvider.notifier)
        .mutate((r) => BackupService(r.db).restore(parsed));
    if (mounted) showToast(context, 'Backup restored');
  });

  Future<void> _csv() => _run(() async {
    final gb = ref.read(gradebookProvider).value!;
    final f = await _temp(
      'gradetrack-scores-$_stamp.csv',
      utf8.encode(ExportService.scoresCsv(gb)),
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path, mimeType: 'text/csv')],
        title: 'GradeTrack scores',
      ),
    );
  });

  Future<void> _pdf() => _run(() async {
    final gb = ref.read(gradebookProvider).value!;
    final term = gb.currentTerm;
    if (term == null) throw const DataException('Add a term first.');
    final bytes = await ExportService.termReportPdf(gb, term);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'grade-report-${term.schoolYear}-${term.kind.code}.pdf',
    );
  });

  Future<void> _sample() => _run(() async {
    final ok = await confirmAction(
      context,
      title: 'Load the sample semester?',
      body: 'Adds three terms with sample subjects and scores (Juan, BSIT). Existing data is kept.',
      confirm: 'Load',
      destructive: false,
    );
    if (!ok) return;
    final hasProfile = ref.read(gradebookProvider).value?.profile != null;
    await ref
        .read(gradebookProvider.notifier)
        .mutate((r) => SampleData.seed(r.db, withProfile: !hasProfile));
    if (mounted) showToast(context, 'Sample data added');
  });

  Future<void> _wipe() => _run(() async {
    final ok = await confirmAction(
      context,
      title: 'Delete all data?',
      body: 'Every term, subject, score and your profile will be erased from this phone. Export a backup first if you may need it.',
      confirm: 'Delete all',
    );
    if (!ok) return;
    await ref.read(gradebookProvider.notifier).mutate((r) => r.wipe());
    await ref.read(prefsProvider).setOnboarded(false);
    ref.read(lockProvider.notifier).unlock();
    if (mounted) context.go('/onboarding');
  });

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    final gb = ref.watch(gradebookProvider).value;
    return PageScaffold(
      title: 'Backup & export',
      children: [
        GtCard(
          color: c.primarySoft,
          borderColor: Colors.transparent,
          child: Row(
            children: [
              Icon(Ph.deviceMobile, color: c.primaryText),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'GradeTrack keeps everything on this phone and is excluded from cloud backup. Export a backup file before changing phones or reinstalling.',
                  style: context.tt.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        const SectionLabel('Backup'),
        _Action(
          icon: Ph.export,
          title: 'Export backup',
          hint: 'A .json file with all terms, subjects and scores',
          onTap: _exportBackup,
        ),
        _Action(
          icon: Ph.downloadSimple,
          title: 'Restore from backup',
          hint: 'Replaces the data on this phone',
          onTap: _import,
        ),
        const SectionLabel('Export'),
        _Action(
          icon: Ph.filePdf,
          title: 'Grade report (PDF)',
          hint: gb?.currentTerm == null
              ? 'Current term'
              : 'For ${gb!.currentTerm!.shortLabel}',
          onTap: _pdf,
        ),
        _Action(
          icon: Ph.fileCsv,
          title: 'All scores (CSV)',
          hint: 'Opens in Sheets or Excel',
          onTap: _csv,
        ),
        const SectionLabel('Other'),
        _Action(
          icon: Ph.student,
          title: 'Load sample semester',
          hint: 'Demo data from the project proposal',
          onTap: _sample,
        ),
        _Action(
          icon: Ph.trash,
          title: 'Delete all data',
          hint: 'Cannot be undone',
          onTap: _wipe,
          color: c.red,
        ),
        const SizedBox(height: 16),
        Text(
          'Backup format: ${BackupService.appId} schema ${gb == null ? '' : 1}. Subjects: ${gb?.subjects.length ?? 0} · Scores: ${gb?.scores.length ?? 0}.',
          style: context.tt.bodySmall!.copyWith(color: c.faint),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GtCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.raised,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: color ?? c.text),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.tt.titleSmall!.copyWith(color: color),
                  ),
                  Text(hint, style: context.tt.bodySmall),
                ],
              ),
            ),
            Icon(Ph.caretRight, size: 14, color: c.faint),
          ],
        ),
      ),
    );
  }
}
