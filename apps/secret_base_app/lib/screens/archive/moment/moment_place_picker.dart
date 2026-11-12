import 'package:flutter/material.dart';

import '../../../features/moment_loop/application/moment_loop_controller.dart';
import '../../../v2/v2.dart';
import '../map_screen.dart';

/// A 비밀지도 place linked to a record.
class MomentPlace {
  final int? id;
  final String name;
  const MomentPlace({required this.id, required this.name});
}

class _PinRow {
  final int id;
  final String name;
  final String? category;
  const _PinRow(this.id, this.name, this.category);
}

class _PickResult {
  final MomentPlace? place;
  final bool openMap;
  final bool retry;
  final bool clear;
  const _PickResult.place(this.place)
    : openMap = false,
      retry = false,
      clear = false;
  const _PickResult.openMap()
    : place = null,
      openMap = true,
      retry = false,
      clear = false;
  const _PickResult.retry()
    : place = null,
      openMap = false,
      retry = true,
      clear = false;
  const _PickResult.clear()
    : place = null,
      openMap = false,
      retry = false,
      clear = true;
}

/// Result of [showMomentPlacePicker]: [cleared] when the user removed the
/// place, otherwise the chosen [place] (null = closed without a choice).
typedef MomentPlacePick = ({MomentPlace? place, bool cleared});

/// "장소 붙이기": saved 비밀지도 places, with a way to add one on the map
/// (a pin added there is picked automatically).
Future<MomentPlacePick?> showMomentPlacePicker(
  BuildContext context, {
  required MomentLoopController controller,
  int? selectedId,
}) async {
  Future<List<_PinRow>?> load() async {
    try {
      final pins = await controller.loadMapPins();
      return pins.map((p) => _PinRow(p.id, p.name, p.category)).toList();
    } catch (_) {
      return null;
    }
  }

  var pins = await load();
  while (true) {
    if (!context.mounted) return null;
    final result = await showV2Sheet<_PickResult>(
      context,
      title: '장소 붙이기',
      subtitle: '비밀지도에 저장한 장소와 기록을 이어 줘요',
      builder: (ctx) => _PlacePicker(pins: pins, selectedId: selectedId),
    );
    if (!context.mounted || result == null) return null;
    if (result.clear) return (place: null, cleared: true);
    if (result.retry) {
      pins = await load();
      continue;
    }
    if (result.openMap) {
      final before = (pins ?? const <_PinRow>[]).map((p) => p.id).toSet();
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const MapScreen(closeAsModal: true),
        ),
      );
      if (!context.mounted) return null;
      pins = await load();
      final fresh = (pins ?? const <_PinRow>[])
          .where((p) => !before.contains(p.id))
          .toList();
      if (fresh.isNotEmpty) {
        return (
          place: MomentPlace(id: fresh.last.id, name: fresh.last.name),
          cleared: false,
        );
      }
      continue;
    }
    return (place: result.place, cleared: false);
  }
}

class _PlacePicker extends StatefulWidget {
  final List<_PinRow>? pins;
  final int? selectedId;
  const _PlacePicker({required this.pins, required this.selectedId});

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pins = widget.pins;
    if (pins == null) {
      return V2ErrorState(
        title: '장소를 불러오지 못했어요',
        body: '연결을 확인하고 다시 시도해 주세요.',
        onRetry: () => Navigator.pop(context, const _PickResult.retry()),
      );
    }
    final q = _query.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? pins
        : pins
              .where(
                (p) =>
                    p.name.toLowerCase().contains(q) ||
                    (p.category ?? '').toLowerCase().contains(q),
              )
              .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pins.isNotEmpty) ...[
          V2TextField(
            label: '장소 찾기',
            hint: '저장한 장소 이름',
            controller: _query,
            prefixIcon: V2Icons.search,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: V2Space.x3),
        ],
        if (pins.isEmpty)
          V2EmptyState(
            illustration: const V2SceneIllustration(V2Scene.map),
            title: '저장한 장소가 아직 없어요',
            body: '지도에서 장소를 추가하면 바로 붙여 드릴게요.',
          )
        else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: V2Space.x6),
            child: Center(child: Text('찾는 장소가 없어요', style: V2Text.cap)),
          )
        else
          V2List(
            children: [
              for (final pin in shown)
                V2ListTile(
                  key: Key('moment_place_${pin.id}'),
                  icon: V2Icons.location,
                  tone: V2Tone.sage,
                  title: pin.name,
                  subtitle: pin.category,
                  showChevron: false,
                  trailing: pin.id == widget.selectedId
                      ? Icon(V2Icons.ok, color: V2Colors.rose600)
                      : null,
                  onTap: () => Navigator.pop(
                    context,
                    _PickResult.place(MomentPlace(id: pin.id, name: pin.name)),
                  ),
                ),
            ],
          ),
        const SizedBox(height: V2Space.x3),
        V2Button(
          key: const Key('moment_place_add_on_map'),
          label: '지도에서 새 장소 추가',
          icon: V2Icons.add,
          variant: V2ButtonVariant.soft,
          onPressed: () => Navigator.pop(context, const _PickResult.openMap()),
        ),
        if (widget.selectedId != null) ...[
          const SizedBox(height: V2Space.x2),
          V2Button(
            key: const Key('moment_place_clear'),
            label: '장소 빼기',
            variant: V2ButtonVariant.text,
            onPressed: () => Navigator.pop(context, const _PickResult.clear()),
          ),
        ],
      ],
    );
  }
}
