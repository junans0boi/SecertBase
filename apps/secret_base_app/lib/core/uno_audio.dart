import 'package:audioplayers/audioplayers.dart';
import 'dart:math';

class UnoAudio {
  UnoAudio._();
  static final UnoAudio instance = UnoAudio._();

  final _sfx = AudioPlayer();
  final _voice = AudioPlayer();
  final _rng = Random();
  bool _enabled = true;

  bool get enabled => _enabled;
  set enabled(bool v) => _enabled = v;

  // Unlock audio on first user interaction (web browser autoplay policy)
  Future<void> unlock() async {
    try {
      await _sfx.setVolume(0);
      await _sfx.play(AssetSource('sounds/uno/card_pick.mp3'));
      await _sfx.stop();
      await _sfx.setVolume(1);
    } catch (_) {}
  }

  Future<void> _playSfx(String asset) async {
    if (!_enabled) return;
    try {
      await _sfx.stop();
      await _sfx.play(AssetSource('sounds/uno/$asset'));
    } catch (_) {}
  }

  Future<void> _playVoice(String asset) async {
    if (!_enabled) return;
    try {
      await _voice.stop();
      await _voice.play(AssetSource('sounds/uno/$asset'));
    } catch (_) {}
  }

  // ── Card pick (tap to select a card) ──────────────────────────────────────
  Future<void> cardPick() => _playSfx('card_pick.mp3');

  // ── Card play (card placed on discard pile) ────────────────────────────────
  Future<void> cardPlay() => _playSfx('card_draw.mp3');

  // ── Deal: cycle through 3 deal sounds ─────────────────────────────────────
  int _dealIdx = 0;
  Future<void> cardDeal() {
    final files = ['deal_1.mp3', 'deal_2.mp3', 'deal_3.mp3'];
    final f = files[_dealIdx % files.length];
    _dealIdx++;
    return _playSfx(f);
  }

  // ── Skip ──────────────────────────────────────────────────────────────────
  Future<void> cardSkip() => _playSfx('card_skip_effect.mp3');

  // ── Reverse ───────────────────────────────────────────────────────────────
  Future<void> cardReverse() async {
    await _playSfx('card_reverse_effect.mp3');
    await Future.delayed(const Duration(milliseconds: 300));
    await _playVoice('voice_reverse.mp3');
  }

  // ── Draw 2 ────────────────────────────────────────────────────────────────
  Future<void> cardDraw2() => _playVoice('voice_draw2.mp3');

  // ── Wild Draw 4 ───────────────────────────────────────────────────────────
  Future<void> cardDraw4() => _playVoice('voice_draw4.mp3');

  // ── Draw stack resolved (cumulative draws) ────────────────────────────────
  Future<void> drawStack() => _playVoice('voice_draw_stack.mp3');

  // ── Color declared (wild / wild_draw4) ────────────────────────────────────
  Future<void> colorDeclared(String color) {
    const map = {
      'green':  'color_green.mp3',
      'red':    'color_red.mp3',
      'yellow': 'color_yellow.mp3',
      'blue':   'color_blue.mp3',
    };
    final f = map[color];
    if (f == null) return Future.value();
    return _playVoice(f);
  }

  // ── UNO call / caught ─────────────────────────────────────────────────────
  Future<void> unoCall() => _playVoice('voice_uno.mp3');
  Future<void> unoCaught() => _playVoice('voice_oops.mp3');

  // ── Game start countdown ──────────────────────────────────────────────────
  Future<void> countdownBeep(int remaining) {
    // remaining: 5,4,3,2,1 → gamestart_5..1
    final n = remaining.clamp(1, 5);
    return _playSfx('gamestart_$n.mp3');
  }

  Future<void> countdownEnd() => _playSfx('gamestart_end.mp3');

  // ── Victory / Defeat ─────────────────────────────────────────────────────
  Future<void> victory() => _playVoice('voice_super.mp3');
  Future<void> defeat() async {
    // voice_oops for loser (funny but fitting)
    await _playVoice('voice_oops.mp3');
    await Future.delayed(const Duration(milliseconds: 600));
    await _playSfx('victory_token.mp3');
  }

  void dispose() {
    _sfx.dispose();
    _voice.dispose();
  }
}
