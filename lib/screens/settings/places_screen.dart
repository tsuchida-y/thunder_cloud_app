import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../navigation/app_routes.dart';
import '../../services/location/current_place.dart';
import '../../services/member/member_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/settings_parts.dart';
import '../../widgets/common/sky_page.dart';

/// 見張る場所（docs/design/Places.html）
///
/// 地名の検索だけで登録する（地図は使わない。決定事項 2026-10-20）。
/// 無料は1か所（「いまいる場所」が分からないときに見張る）、Plus は3か所まで（「いまいる場所」に加えて見張る）。
class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  static const int freeMaxPlaces = 1;
  static const int plusMaxPlaces = 3;

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _memberSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _serverSub;
  Map<String, dynamic>? _member;
  Map<String, dynamic>? _server;
  String? _currentName;
  bool _locationOff = false;

  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  List<PlaceCandidate>? _results;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final uid = MemberService.uid;
    if (uid != null) {
      _memberSub = MemberService.watchMember(uid).listen((doc) => setState(() => _member = doc.data()));
      _serverSub = MemberService.watchServer(uid).listen((doc) => setState(() => _server = doc.data()));
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
    if (mounted) setState(() => _currentName = name);
  }

  @override
  void dispose() {
    _memberSub?.cancel();
    _serverSub?.cancel();
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  bool get _isPlus => MemberService.isPlusActive(_server, DateTime.now());
  List<WatchPlace> get _places => MemberService.placesOf(_member);
  int get _maxPlaces => _isPlus ? PlacesScreen.plusMaxPlaces : PlacesScreen.freeMaxPlaces;

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _results = null;
    });
    final results = await CurrentPlace.search(_query.text);
    if (mounted) {
      setState(() {
        _searching = false;
        _results = results;
      });
    }
  }

  Future<void> _add(PlaceCandidate candidate) async {
    final label = await _askLabel(initial: candidate.shortName);
    if (label == null) return;
    final places = [..._places, WatchPlace(label: label, name: candidate.shortName, location: candidate.location)];
    await MemberService.savePlaces(places.take(_maxPlaces).toList());
    if (!mounted) return;
    setState(() {
      _results = null;
      _query.clear();
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _change(int index) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SettingsCard(
            children: [
              SettingsRow.text('名前を変える', onTap: () => Navigator.of(context).pop('rename')),
              SettingsRow(
                title: Text('この場所を消す', style: AppTextStyles.item(color: AppColors.accent)),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );
    final places = [..._places];
    if (action == 'delete') {
      places.removeAt(index);
      await MemberService.savePlaces(places);
    } else if (action == 'rename') {
      final label = await _askLabel(initial: places[index].label);
      if (label == null) return;
      places[index] = places[index].copyWith(label: label);
      await MemberService.savePlaces(places);
    }
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
          maxLength: 20,
          decoration: const InputDecoration(hintText: '家、学校など'),
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
              child: Text('いまいる場所に加えて、よく行く場所を3か所まで見張れます。', style: note),
            ),
            const SizedBox(height: 14),
            SettingsCard(
              children: [
                SettingsRow(
                  title: Text('いまいる場所', style: AppTextStyles.item()),
                  subtitle: _locationOff ? '位置情報がオフです' : (_currentName ?? ''),
                ),
                for (var i = 0; i < places.length; i++)
                  SettingsRow(
                    title: Text(places[i].label, style: AppTextStyles.item()),
                    subtitle: places[i].name,
                    trailing: TextButton(
                      onPressed: () => _change(i),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
                        textStyle: AppTextStyles.body(color: AppColors.accent).copyWith(fontSize: 14),
                      ),
                      child: const Text('変更'),
                    ),
                  ),
              ],
            ),
            if (remaining > 0) ...[
              const SizedBox(height: 14),
              _AddPlaceButton(remaining: remaining, onPressed: () => _queryFocus.requestFocus()),
              const SizedBox(height: 14),
              _SearchCard(
                controller: _query,
                focusNode: _queryFocus,
                searching: _searching,
                results: _results,
                onSearch: _search,
                onPick: _add,
              ),
            ],
            const Spacer(),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: '無料プランは「いまいる場所」か、手で選んだ1か所です。\n3か所の登録は '),
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

/// 「場所をさがす」
class _SearchCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final List<PlaceCandidate>? results;
  final VoidCallback onSearch;
  final ValueChanged<PlaceCandidate> onPick;

  const _SearchCard({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.results,
    required this.onSearch,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.switchOff, width: 1.5),
    );
    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('場所をさがす', style: AppTextStyles.body().copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSearch(),
                style: AppTextStyles.body().copyWith(height: 1.3),
                decoration: InputDecoration(
                  hintText: '市町村名や住所',
                  filled: true,
                  fillColor: const Color(0xFFF7FAFD),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
                  suffixIcon: IconButton(
                    onPressed: onSearch,
                    tooltip: 'さがす',
                    icon: const Icon(Icons.search_rounded, color: AppColors.textSub),
                  ),
                ),
              ),
              if (searching) ...[
                const SizedBox(height: 12),
                const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              ] else if (results != null && results!.isEmpty) ...[
                const SizedBox(height: 10),
                Text('見つかりませんでした。別の書き方でさがしてください。', style: AppTextStyles.note()),
              ],
            ],
          ),
        ),
        if (results != null)
          for (final candidate in results!)
            SettingsRow.text(
              candidate.name,
              trailing: const Icon(Icons.add_rounded, color: AppColors.accent),
              onTap: () => onPick(candidate),
            ),
      ],
    );
  }
}
