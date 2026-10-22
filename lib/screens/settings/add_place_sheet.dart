import 'package:flutter/material.dart';

import '../../services/location/current_place.dart';
import '../../services/member/member_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_buttons.dart';

/// 「場所を追加」（場所の見せ方_画面一覧.png の「＋で開く『場所を追加』」）
///
/// ホームの「＋」と、見張る場所の画面から開く。地名の検索だけで選ぶ（地図は使わない。決定事項 2026-10-20）。
/// 追加したら true を返す。
class AddPlaceSheet extends StatefulWidget {
  /// これまでに登録した場所（呼び名がかぶらないようにするのと、残りの数に使う）
  final List<WatchPlace> places;

  /// 登録できる数（無料 1、Plus 3）
  final int maxPlaces;
  final String initialQuery;

  const AddPlaceSheet({super.key, required this.places, required this.maxPlaces, this.initialQuery = ''});

  static const List<String> labels = ['家', '学校', '職場', '実家'];

  static Future<bool> show(BuildContext context, {required List<WatchPlace> places, required int maxPlaces, String initialQuery = ''}) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF4F8FC),
      barrierColor: const Color(0x730B1630),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => AddPlaceSheet(places: places, maxPlaces: maxPlaces, initialQuery: initialQuery),
    );
    return added == true;
  }

  @override
  State<AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<AddPlaceSheet> {
  late final TextEditingController _query = TextEditingController(text: widget.initialQuery);
  List<PlaceCandidate>? _results;
  PlaceCandidate? _picked;
  late String _label = AddPlaceSheet.labels.firstWhere(
    (l) => widget.places.every((p) => p.label != l),
    orElse: () => AddPlaceSheet.labels.first,
  );
  bool _searching = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _results = null;
      _picked = null;
    });
    final results = await CurrentPlace.search(_query.text);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _results = results;
      _picked = results.isEmpty ? null : results.first;
    });
  }

  Future<void> _add() async {
    final picked = _picked;
    if (picked == null) return;
    setState(() => _saving = true);
    final places = [...widget.places, WatchPlace(label: _label, name: picked.shortName, location: picked.location)];
    await MemberService.savePlaces(places.take(widget.maxPlaces).toList());
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.maxPlaces - widget.places.length;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              Row(
                children: [
                  Expanded(child: Text('場所を追加', style: AppTextStyles.pageTitle().copyWith(fontSize: 18))),
                  IconTapButton(
                    icon: Icons.close_rounded,
                    semanticLabel: '閉じる',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              Text(
                '追加した場所は、ホームの上から切り替えて見られます。雲が出たら通知も届きます。',
                style: AppTextStyles.note(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _query,
                autofocus: widget.initialQuery.isEmpty,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                style: AppTextStyles.body().copyWith(height: 1.3),
                decoration: InputDecoration(
                  hintText: '市町村名や住所',
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSub),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border,
                ),
              ),
              const SizedBox(height: 12),
              if (_searching)
                const Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)))
              else if (_results != null && _results!.isEmpty)
                Text('見つかりませんでした。別の書き方でさがしてください。', style: AppTextStyles.note())
              else if (_results != null)
                DecoratedBox(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      for (var i = 0; i < _results!.length; i++)
                        _CandidateRow(
                          candidate: _results![i],
                          selected: identical(_results![i], _picked),
                          divider: i < _results!.length - 1,
                          onTap: () => setState(() => _picked = _results![i]),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Text('呼び名', style: AppTextStyles.body().copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in AddPlaceSheet.labels)
                    _LabelChip(label: label, selected: label == _label, onTap: () => setState(() => _label = label)),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'この場所を追加（あと$remainingか所）',
                onPressed: _picked == null || _saving || remaining <= 0 ? null : _add,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  final PlaceCandidate candidate;
  final bool selected;
  final bool divider;
  final VoidCallback onTap;

  const _CandidateRow({required this.candidate, required this.selected, required this.divider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.chip : null,
            border: divider ? const Border(bottom: BorderSide(color: AppColors.divider)) : null,
          ),
          child: Row(
            children: [
              Icon(Icons.place_outlined, size: 20, color: selected ? AppColors.accent : AppColors.textSub),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  candidate.shortName,
                  style: AppTextStyles.item().copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                ),
              ),
              if (candidate.region != null && candidate.region != candidate.shortName)
                Text(candidate.region!, style: AppTextStyles.caption()),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LabelChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primary : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.switchOff)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget, minWidth: 64),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.body(color: selected ? Colors.white : AppColors.text)
                  .copyWith(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}
