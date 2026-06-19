// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class UnoAudio {
  UnoAudio._();
  static final UnoAudio instance = UnoAudio._();

  bool _enabled = true;
  int _dealIdx = 0;

  bool get enabled => _enabled;
  set enabled(bool v) => _enabled = v;

  static String _url(String file) => 'assets/assets/sounds/uno/$file';

  Future<void> unlock() async {}

  Future<void> _play(String file) async {
    if (!_enabled) return;
    try {
      final audio = html.AudioElement(_url(file));
      await audio.play();
    } catch (_) {}
  }

  // ── 카드 선택 (내 패에서 카드 탭) ─────────────────────────────────────────
  Future<void> cardPick() => _play('card_pick.mp3');

  // ── 카드 1장 뽑기 (더미에서) ─────────────────────────────────────────────
  Future<void> cardDrawFromDeck() => _play('card_draw.mp3');

  // ── 딜링 (게임 시작 시 카드 한 장씩 지급) ─────────────────────────────────
  // 7장이므로 1→deal_1, 2→deal_2, 3→deal_3, 4→deal_1, 5→deal_2, 6→deal_3, 7→deal_1
  static const _dealFiles = ['deal_1.mp3', 'deal_2.mp3', 'deal_3.mp3'];
  Future<void> cardDeal() => _play(_dealFiles[_dealIdx++ % _dealFiles.length]);

  // ── Skip 효과 + 목소리 ────────────────────────────────────────────────────
  Future<void> cardSkip() async {
    await _play('card_skip_effect.mp3');
    await Future.delayed(const Duration(milliseconds: 200));
    await _play('voice_skip.mp3');
  }

  // ── Reverse 효과 + 목소리 ────────────────────────────────────────────────
  Future<void> cardReverse() async {
    await _play('card_reverse_effect.mp3');
    await Future.delayed(const Duration(milliseconds: 300));
    await _play('voice_reverse.mp3');
  }

  // ── 드로우 해소 목소리 ────────────────────────────────────────────────────
  // +2 단독(2장) → M_07_Draw2
  // +4 단독(4장) → M_08_Draw4
  // 누적(그 외)   → M_09_DrawCs
  Future<void> drawResolved(int count, String? type) {
    if (count == 2 && type == 'draw2') {
      return _play('voice_draw2.mp3');
    } else if (count == 4 && type == 'wild_draw4') {
      return _play('voice_draw4.mp3');
    } else {
      return _play('voice_draw_stack.mp3');
    }
  }

  // ── 색상 선언 (Wild / +4 이후) ────────────────────────────────────────────
  Future<void> colorDeclared(String color) {
    const map = {
      'green': 'color_green.mp3',
      'red': 'color_red.mp3',
      'yellow': 'color_yellow.mp3',
      'blue': 'color_blue.mp3',
    };
    final f = map[color];
    if (f == null) return Future.value();
    return _play(f);
  }

  // ── UNO 선언 / 잡기 ───────────────────────────────────────────────────────
  Future<void> unoCall() => _play('voice_uno.mp3');
  Future<void> unoCaught() => _play('voice_oops.mp3');

  // ── 선물 / 장난 리액션 ───────────────────────────────────────────────────
  Future<void> giftReaction(String type) {
    const map = {
      'cake': 'gift_cake_9hit.wav',
      'candy': 'gift_candy.wav',
      'coffee': 'gift_coffee.wav',
      'flyby': 'gift_flyby.wav',
      'pillow': 'gift_pillow_9hit.wav',
      'pizza': 'gift_pizza.wav',
      'sportscar': 'gift_sportscar.wav',
      'tomato': 'item_tomato.wav',
    };
    final file = map[type];
    if (file == null) return Future.value();
    return _play(file);
  }

  // ── 게임 시작 카운트다운 ──────────────────────────────────────────────────
  // remaining: 5→4→3→2→1, gamestart_5.mp3 ~ gamestart_1.mp3 순으로 재생
  Future<void> countdownBeep(int remaining) {
    final n = remaining.clamp(1, 5);
    return _play('gamestart_$n.mp3');
  }

  Future<void> countdownEnd() => _play('gamestart_end.mp3');

  // ── 턴 타이머 카운트다운 ──────────────────────────────────────────────────
  // 5초 이하 매 초마다 tick, 0초에 end
  Future<void> timerTick() => _play('timer_tick.mp3');
  Future<void> timerEnd() => _play('timer_end.mp3');

  // ── 승리 / 패배 ──────────────────────────────────────────────────────────
  Future<void> victory() => _play('voice_super.mp3');
  Future<void> defeat() async {
    await _play('voice_oops.mp3');
    await Future.delayed(const Duration(milliseconds: 600));
    await _play('victory_token.mp3');
  }

  void dispose() {}
}
