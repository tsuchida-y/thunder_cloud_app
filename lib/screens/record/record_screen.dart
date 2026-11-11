import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/sky/report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/sky_geometry.dart';
import '../../utils/time_text.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/settings_parts.dart';
import '../../widgets/common/sky_page.dart';

/// 記録（docs/design/Record.html）
///
/// ことし「見えた」と答えた入道雲の一覧。無料でも使える。
/// 写真と共有は v2.0 では作らない（2026-10-21 決定）。
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  late final Future<List<SeenRecord>> _records = ReportService.seenThisYear();

  @override
  Widget build(BuildContext context) {
    return SkyPage(
      gradient: SkyGradient.light,
      child: FutureBuilder<List<SeenRecord>>(
        future: _records,
        builder: (context, snap) {
          final records = snap.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(title: AppLocalizations.of(context).recordLabel),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  children: [
                    Text(AppLocalizations.of(context).recordYear(DateTime.now().year), style: AppTextStyles.headline(color: AppColors.text, fontSize: 22)),
                    if (records != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          AppLocalizations.of(context).recordDays(ReportService.countDays(records)),
                          style: AppTextStyles.body(color: AppColors.textSub).copyWith(fontSize: 14, height: 1.2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (records == null && !snap.hasError)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                )
              else if (records == null || records.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    snap.hasError
                        ? AppLocalizations.of(context).recordLoadFailed
                        : AppLocalizations.of(context).recordEmpty,
                    style: AppTextStyles.body(color: AppColors.textSub).copyWith(fontSize: 14),
                  ),
                )
              else
                _SeenList(records: records),
            ],
          );
        },
      ),
    );
  }
}

/// 「見えた入道雲」のカード
class _SeenList extends StatelessWidget {
  final List<SeenRecord> records;

  const _SeenList({required this.records});

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(AppLocalizations.of(context).homeTodayCloudSeen, style: AppTextStyles.body().copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        for (final r in records) _SeenRow(record: r),
      ],
    );
  }
}

class _SeenRow extends StatelessWidget {
  final SeenRecord record;

  const _SeenRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final date = record.seenAt.toLocal();
    final from = record.from;
    final to = record.to;
    final time = from != null && to != null
        ? AppLocalizations.of(context).timeRange(TimeText.clock(from), TimeText.clock(to))
        : AppLocalizations.of(context).aroundTime(TimeText.clock(record.seenAt));
    final text = AppLocalizations.of(context).recordRowText(SkyGeometry.directionName(record.bearingDeg), record.distanceKm.round(), time);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text('${date.month}/${date.day}', style: AppTextStyles.number(fontSize: 14).copyWith(fontWeight: FontWeight.w400)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.body().copyWith(fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }
}
