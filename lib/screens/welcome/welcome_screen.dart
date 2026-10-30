import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/location/current_place.dart';
import '../../services/member/member_service.dart';
import '../../services/notification/cloud_notifications.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/logger.dart';
import '../../widgets/common/app_buttons.dart';
import '../../widgets/common/sky_card.dart';
import '../../widgets/common/sky_page.dart';
import '../home/home_screen.dart';

/// はじめての起動（docs/design/Welcome.html）
///
/// 「使用中の位置情報」と「通知」だけをお願いする。「常に」はここでは聞かない（AlwaysAllow.html で1回だけ）。
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  static const String _doneKey = 'welcome_done';

  static bool isDone(SharedPreferences prefs) => prefs.getBool(_doneKey) == true;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _busy = false;

  Future<void> _allowAndStart() async {
    setState(() => _busy = true);
    try {
      // 通知の宛先を members に書くために、先にログインしておく（通信できなければホームでやり直す）
      await MemberService.ensureSignedIn().catchError((Object e) {
        AppLogger.warning('はじめてのログインに失敗: $e', tag: 'WelcomeScreen');
        return '';
      });
      await CurrentPlace.request();
      await CloudNotifications.request();
    } finally {
      await _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WelcomeScreen._doneKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return SkyPage(
      gradient: SkyGradient.day,
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(alignment: Alignment.centerLeft, child: _WelcomeCloud()),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text('入道雲サーチ', style: AppTextStyles.headline(fontSize: 34).copyWith(height: 1.3)),
          ),
          const SizedBox(height: 16),
          Text(
            'あなたの場所から見える空に入道雲が現れたら、どの方角かをお知らせします。',
            style: AppTextStyles.body(color: Colors.white).copyWith(fontSize: 16),
          ),
          const Spacer(),
          const SizedBox(height: 16),
          const SkyCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _PermissionRow(
                  icon: Icons.place_outlined,
                  title: '位置情報（アプリの使用中）',
                  body: '開いた場所の空を調べ、その場所の空を見張ります。',
                  divider: true,
                ),
                _PermissionRow(
                  icon: Icons.notifications_none_rounded,
                  title: '通知',
                  body: '入道雲が見えたときに、1つの雲につき1回だけお知らせします。',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: '許可してはじめる', onPressed: _busy ? null : _allowAndStart),
          const SizedBox(height: 16),
          Text(
            '移動先の空も見張る設定は、あとでご案内します。',
            textAlign: TextAlign.center,
            style: AppTextStyles.note(),
          ),
          const SizedBox(height: 4),
          Center(child: TextLinkButton(label: 'あとで設定する', onPressed: _busy ? null : _finish)),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final bool divider;

  const _PermissionRow({required this.icon, required this.title, required this.body, this.divider = false});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: divider ? const Border(bottom: BorderSide(color: AppColors.dividerOnCard)) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.chip, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.item().copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(body, style: AppTextStyles.note()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 題名の上の雲と光（120×70）
class _WelcomeCloud extends StatelessWidget {
  const _WelcomeCloud();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(child: CustomPaint(size: const Size(120, 70), painter: _WelcomeCloudPainter()));
  }
}

class _WelcomeCloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = Colors.white;
    final cloud = Path()
      ..moveTo(14, 66)
      ..cubicTo(8, 52, 22, 42, 34, 46)
      ..cubicTo(32, 26, 56, 18, 66, 32)
      ..cubicTo(70, 10, 98, 8, 102, 32)
      ..cubicTo(116, 32, 120, 54, 108, 66)
      ..close();
    canvas.drawPath(cloud, white);
    final sparkle = Path()
      ..moveTo(10, 10)
      ..relativeLineTo(2, 6)
      ..relativeLineTo(6, 2)
      ..relativeLineTo(-6, 2)
      ..relativeLineTo(-2, 6)
      ..relativeLineTo(-2, -6)
      ..relativeLineTo(-6, -2)
      ..relativeLineTo(6, -2)
      ..close();
    canvas.drawPath(sparkle, white);
  }

  @override
  bool shouldRepaint(_WelcomeCloudPainter oldDelegate) => false;
}
