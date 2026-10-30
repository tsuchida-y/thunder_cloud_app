import 'package:flutter/material.dart';

import '../../services/member/member_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/app_buttons.dart';
import '../../widgets/common/settings_parts.dart';

/// 通知しない時間を選ぶ（Settings.html の「通知しない時間」から。初めは「なし」）
///
/// 決めたら [QuietHours] を、「なし」にしたら null を返す。閉じただけなら何も返さない。
class QuietHoursSheet extends StatefulWidget {
  final QuietHours? current;

  const QuietHoursSheet({super.key, required this.current});

  /// 戻り値: 選んだ結果（record の changed が false なら変更なし）
  static Future<({bool changed, QuietHours? value})> show(BuildContext context, QuietHours? current) async {
    final result = await showModalBottomSheet<({QuietHours? value})>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => QuietHoursSheet(current: current),
    );
    return (changed: result != null, value: result?.value);
  }

  @override
  State<QuietHoursSheet> createState() => _QuietHoursSheetState();
}

class _QuietHoursSheetState extends State<QuietHoursSheet> {
  late bool _enabled = widget.current != null;
  late int _start = widget.current?.startMinutes ?? 22 * 60;
  late int _end = widget.current?.endMinutes ?? 6 * 60;

  Future<void> _pick(bool start) async {
    final minutes = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    setState(() {
      final value = picked.hour * 60 + picked.minute;
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: AppColors.switchOff, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 14),
            Text('通知しない時間', style: AppTextStyles.headline(color: AppColors.text, fontSize: 22)),
            const SizedBox(height: 6),
            Text('空が暗いあいだ（夜）は自動で休みます', style: AppTextStyles.note()),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                SettingsRow.text(
                  '通知しない時間を決める',
                  trailing: SkySwitch(
                    value: _enabled,
                    semanticLabel: '通知しない時間を決める',
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ),
                if (_enabled) ...[
                  SettingsRow.text('はじめ', trailing: SettingsValue(QuietHours.clock(_start)), onTap: () => _pick(true)),
                  SettingsRow.text('おわり', trailing: SettingsValue(QuietHours.clock(_end)), onTap: () => _pick(false)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '決める',
              onPressed: () => Navigator.of(context).pop((value: _enabled ? QuietHours(_start, _end) : null)),
            ),
          ],
        ),
      ),
    );
  }
}
