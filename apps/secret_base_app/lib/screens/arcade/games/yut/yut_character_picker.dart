import 'package:flutter/material.dart';

import '../../../../core/main_design.dart';
import '../../../../core/socket_service.dart';
import 'yut_figures.dart';
import 'yut_models.dart';
import 'yut_stat_bars.dart';

/// 윷놀이 로비의 캐릭터 고르기. 홍길동·놀부·미호 중 하나를 고르고,
/// 상대가 고른 캐릭터는 누를 수 없다(서버도 `character_taken`으로 막는다).
/// 고르지 않으면 서버가 겹치지 않게 정해 준다.
class YutCharacterPicker extends StatelessWidget {
  final Color color;

  const YutCharacterPicker({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    final socket = SocketService();
    final me = socket.userId;
    final picks = socket.lobbyCharacterSelections;
    final mine = picks[me];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🎭', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              '캐릭터',
              style: mainBody(
                size: 13,
                color: kMainInk,
                weight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mine == null ? '고르지 않으면 자동으로 정해져요' : '상대와 겹치지 않아요',
                style: mainBody(size: 12, color: kMainMuted, height: 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final id in SocketService.yutCharacterIds) ...[
              Expanded(
                child: _CharacterCard(
                  id: id,
                  color: color,
                  state: picks[me] == id
                      ? _Pick.mine
                      : picks.entries.any((e) => e.key != me && e.value == id)
                      ? _Pick.taken
                      : _Pick.free,
                  onTap: () => socket.selectYutLobbyCharacter(id),
                ),
              ),
              if (id != SocketService.yutCharacterIds.last)
                const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

enum _Pick { free, mine, taken }

class _CharacterCard extends StatelessWidget {
  final String id;
  final Color color;
  final _Pick state;
  final VoidCallback onTap;

  const _CharacterCard({
    required this.id,
    required this.color,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = yutCharacterNames[id] ?? id;
    final taken = state == _Pick.taken;
    final mine = state == _Pick.mine;
    final status = mine
        ? '내 선택'
        : taken
        ? '상대 선택'
        : '고르기';
    return Semantics(
      button: !taken,
      enabled: !taken,
      selected: mine,
      label: '$name, $status',
      child: GestureDetector(
        key: ValueKey('yut_pick_$id'),
        behavior: HitTestBehavior.opaque,
        onTap: taken ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          decoration: BoxDecoration(
            color: mine ? color.withValues(alpha: 0.12) : kMainPaperSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: mine ? color : kMainLine,
              width: mine ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              YutFigure(
                height: 78,
                team: color,
                spec: YutFigureSpec(character: id),
                dimmed: taken,
                selected: mine,
                badge: false,
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: mainBody(
                  size: 13,
                  color: taken ? kMainMuted : kMainInk,
                  weight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              Text(
                kYutCharacterBlurb[id] ?? '',
                style: mainBody(size: 12, color: kMainSub, height: 1.2),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: YutStatBars(
                  stats: yutCharacterStatsFor(id),
                  color: taken ? kMainMuted : color,
                  textColor: taken ? kMainMuted : kMainInk,
                  compact: true,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                status,
                style: mainBody(
                  size: 12,
                  color: mine ? color : kMainMuted,
                  weight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
