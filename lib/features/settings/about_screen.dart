import 'package:lcc_gradetrack/ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/page_scaffold.dart';
import '../../shared/widgets/primitives.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.gt;
    return PageScaffold(
      title: 'About',
      children: [
        const SizedBox(height: 8),
        Center(
          child: Image.asset(
            'assets/brand/lcc_logo.png',
            width: 140,
            height: 140,
            cacheWidth: 420,
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text('LCC GradeTrack', style: context.tt.headlineSmall)),
        Center(
          child: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, s) => Text(
              s.hasData
                  ? 'Version ${s.data!.version} (${s.data!.buildNumber})'
                  : ' ',
              style: mono(12, color: c.muted),
            ),
          ),
        ),
        const SizedBox(height: 20),
        GtCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What it does', style: context.tt.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Record quiz, assignment, activity and exam scores. GradeTrack computes component averages, weighted subject grades, 1.00–5.00 equivalents and your units-weighted GWA.',
                style: context.tt.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GtCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(PhosphorIconsRegular.shieldCheck, color: c.laurel),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Privacy', style: context.tt.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Your data never leaves this phone. There are no accounts, no analytics and no internet access. Grades are stored in a local SQLite database.',
                      style: context.tt.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GtCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Note', style: context.tt.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Computed grades depend on the scores and weights you enter. Your official grades come from the registrar.',
                style: context.tt.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'LCC GradeTrack',
            applicationIcon: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                'assets/brand/lcc_logo_512.png',
                width: 64,
                height: 64,
              ),
            ),
          ),
          icon: const Icon(PhosphorIconsRegular.fileText, size: 18),
          label: const Text('Open-source licenses'),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Legacy College of Compostela · IT 126 Mobile Development',
            style: context.tt.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
