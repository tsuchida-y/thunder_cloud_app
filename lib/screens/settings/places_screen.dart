import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/lat_lng.dart';
import '../../models/sky_cloud.dart';
import '../../navigation/app_routes.dart';
import '../../services/location/current_place.dart';
import '../../services/member/member_service.dart';
import '../../services/sky/sky_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_buttons.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/settings_parts.dart';
import '../../widgets/common/sky_page.dart';
import 'add_place_sheet.dart';

/// 見張る場所（docs/design/Places.html と、場所の見せ方_画面一覧.png の「見張る場所（設定からも）」）
///
/// 地名の検索だけで登録する（地図は使わない。決定事項 2026-10-20）。
/// 無料は1か所（「いまいる場所」が分からないときに見張る）、Plus は3か所まで（「いまいる場所」に加えて見張り、
/// ホームの上のチップで切り替えて見られる）。
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _memberSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _serverSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cloudSub;
  Map<String, dynamic>? _member;
  Map<String, dynamic>? _server;
  List<SkyCloud> _clouds = const [];
  String? _currentName;
  LatLng? _currentPoint;
  bool _locationOff = false;

  final TextEditingController _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    final uid = MemberService.uid;
    if (uid != null) {
      _memberSub = MemberService.watchMember(uid).listen((doc) => setState(() => _member = doc.data()));
      _serverSub = MemberService.watchServer(uid).listen((doc) => setState(() => _server = doc.data()));
      // 見張っている場所のいまの空を出して、本当に見張っていると分かるようにする
      _cloudSub = SkyRepository.watchActiveClouds().listen((snap) {
        setState(() => _clouds = snap.docs.map(SkyCloud.fromDoc).whereType<SkyCloud>().toList());
      });
    }
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final access = await CurrentPlace.access();
    if (access != LocationAccess.granted) {
      if (mounted) setState(() => _locationOff = true);
      return;
    }
    final point = await CurrentPlace.lastKnown();
    final name = point == null ? null : await CurrentPlace.placeName(point);
    if (mounted) {
      setState(() {
        _currentPoint = point;
        _currentName = name;
      });
    }
  }

  @override
  void dispose() {
    _memberSub?.cancel();
    _serverSub?.cancel();
    _cloudSub?.cancel();
    _query.dispose();
    super.dispose();
  }

  bool get _isPlus => MemberService.isPlusActive(_server, DateTime.now());
  List<WatchPlace> get _places => MemberService.placesOf(_member);
  int get _maxPlaces => SkyRules.maxPlaces(isPlus: _isPlus);

  /// いまいる場所を見張っているか（位置情報が使えて、場所が分かっている）
  bool get _currentWatched => !_locationOff && (_currentPoint != null || _member?['location'] != null);

  /// 登録した i 番目の場所を見張っているか（サーバーの watchPointsOf と同じ決まり）
  ///
  /// いまいる場所といっしょに、無料は1か所、Plus は3か所まで見張る（2026-10-27、無料でも1か所）。
  bool _placeWatched(int index) => index < _maxPlaces;

  /// その場所に、いま見える範囲の雲があるか
  bool _hasCloudAt(LatLng point) {
    final range = SkyRules.rangeKm(isPlus: _isPlus, settingKm: MemberSettings.fromMember(_member).rangeKm);
    return _clouds.where((c) => c.isVisible).any((c) => c.viewFrom(point).distanceKm <= range);
  }

  Future<void> _openAdd({String query = ''}) async {
    await AddPlaceSheet.show(context, places: _places, maxPlaces: _maxPlaces, initialQuery: query);
    _query.clear();
  }

  Future<void> _rename(int index) async {
    final places = [..._places];
    final label = await _askLabel(initial: places[index].label);
    if (label == null) return;
    places[index] = places[index].copyWith(label: label);
    await MemberService.savePlaces(places);
  }

  Future<void> _delete(int index) async {
    final places = [..._places];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text('「${places[index].label}」を消しますか？', style: AppTextStyles.pageTitle()),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('やめる')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('消す')),
        ],
      ),
    );
    if (ok != true) return;
    places.removeAt(index);
    await MemberService.savePlaces(places);
  }

  /// 場所の名前（「家」「学校」）をたずねる。やめたら null
  Future<String?> _askLabel({required String initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: Text('場所の名前', style: AppTextStyles.pageTitle()),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: AddPlaceSheet.maxLabelLength,
          decoration: const InputDecoration(hintText: '例：家、おばあちゃんの家、塾'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('やめる')),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.of(context).pop(text.isEmpty ? initial : text);
            },
            child: const Text('登録する'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final places = _places;
    final remaining = _maxPlaces - places.length;
    final note = AppTextStyles.body(color: AppColors.textSub).copyWith(fontSize: 14);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SkyPage(
        gradient: SkyGradient.light,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader(title: '見張る場所'),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('いまいる場所に加えて、よく行く場所を3か所まで見張れます。ホームの上のチップで切り替えて見られます。', style: note),
            ),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                _PlaceRow(
                  icon: Icons.my_location_rounded,
                  label: 'いまいる場所',
                  placeName: _locationOff ? '位置情報がオフです' : _currentName,
                  watched: _currentWatched,
                  hasCloud: _currentPoint != null && _hasCloudAt(_currentPoint!),
                ),
                for (var i = 0; i < places.length; i++)
                  _PlaceRow(
                    icon: _iconFor(places[i].label),
                    label: places[i].label,
                    placeName: places[i].name,
                    watched: _placeWatched(i),
                    hasCloud: _hasCloudAt(places[i].location),
                    onRename: () => _rename(i),
                    onDelete: () => _delete(i),
                  ),
              ],
            ),
            if (remaining > 0) ...[
              const SizedBox(height: 14),
              _AddPlaceButton(remaining: remaining, onPressed: _openAdd),
              const SizedBox(height: 14),
              SettingsCard(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('場所をさがす', style: AppTextStyles.body().copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _query,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (text) => _openAdd(query: text),
                          style: AppTextStyles.body().copyWith(height: 1.3),
                          decoration: InputDecoration(
                            hintText: '市町村名や住所',
                            filled: true,
                            fillColor: const Color(0xFFF7FAFD),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.switchOff, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.switchOff, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const Spacer(),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: '無料プランは「いまいる場所」と、登録した1か所です。\n3か所の登録は '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => AppRoutes.openPlus(context),
                    child: Text('Plus', style: AppTextStyles.caption(color: AppColors.accent).copyWith(decoration: TextDecoration.underline, height: 1.6)),
                  ),
                ),
                const TextSpan(text: ' の機能です。'),
              ]),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption().copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String label) => switch (label) {
        '家' => Icons.home_outlined,
        '学校' => Icons.school_outlined,
        '職場' => Icons.work_outline_rounded,
        '実家' => Icons.cottage_outlined,
        _ => Icons.place_outlined,
      };
}

/// 見張る場所の1行（「家」「盛岡市 ・ 見えています」「変更」「ごみ箱」）
class _PlaceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? placeName;
  final bool watched;
  final bool hasCloud;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _PlaceRow({
    required this.icon,
    required this.label,
    required this.placeName,
    required this.watched,
    required this.hasCloud,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final note = AppTextStyles.note().copyWith(height: 1.4);
    final status = !watched
        ? TextSpan(text: '見張っていません', style: note)
        : hasCloud
            ? TextSpan(text: '見えています', style: note.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700))
            : TextSpan(text: '静かな空', style: note);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.text),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.item()),
                const SizedBox(height: 2),
                Text.rich(TextSpan(children: [
                  if (placeName != null && placeName!.isNotEmpty) TextSpan(text: '$placeName ・ ', style: note),
                  status,
                ])),
              ],
            ),
          ),
          if (onRename != null)
            TextButton(
              onPressed: onRename,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
                textStyle: AppTextStyles.body(color: AppColors.accent)
                    .copyWith(fontSize: 14, decoration: TextDecoration.underline),
              ),
              child: const Text('変更'),
            ),
          if (onDelete != null)
            IconTapButton(icon: Icons.delete_outline_rounded, semanticLabel: '$label を消す', onPressed: onDelete),
        ],
      ),
    );
  }
}

/// 「＋ 場所を追加（あと1か所）」（点線の枠）
class _AddPlaceButton extends StatelessWidget {
  final int remaining;
  final VoidCallback onPressed;

  const _AddPlaceButton({required this.remaining, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: CustomPaint(
        painter: _DashedRRectPainter(),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onPressed,
          child: Center(
            child: Text(
              '＋ 場所を追加（あと$remainingか所）',
              style: AppTextStyles.button(color: AppColors.accent, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.75),
      const Radius.circular(AppRadius.card),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = AppColors.accent;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) => false;
}
