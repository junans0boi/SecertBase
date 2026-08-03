// Reference A preview for the production YutBoard.
// Run: flutter run -d web-server --web-port 53641 \
//   -t lib/screens/arcade/games/yut_design_prototype.dart

import 'package:flutter/material.dart';

import '../../../ui/yut_board.dart';

void main() => runApp(const YutDesignPrototypeApp());

class YutDesignPrototypeApp extends StatelessWidget {
  const YutDesignPrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: Scaffold(
        backgroundColor: const Color(0xFF07111F),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/yut/Summer.png', fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0x14000000),
                        Color(0x08000000),
                        Color(0x78020A16),
                      ],
                      stops: [0, 0.62, 1],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const SafeArea(bottom: false, child: _ReferenceAPreview()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceAPreview extends StatelessWidget {
  const _ReferenceAPreview();

  @override
  Widget build(BuildContext context) {
    return YutBoard(
      gameId: 'reference-a-preview',
      phase: 'moving',
      turn: 'me',
      p1Pieces: const [
        {'position': 0},
        {'position': 27},
        {'position': 0},
        {'position': 0},
      ],
      p2Pieces: const [
        {'position': 0},
        {'position': 22},
        {'position': 0},
        {'position': 0},
      ],
      pendingMoves: const [3],
      onNewGame: _noop,
      onRollStartDice: _noop,
      onThrow: _noop,
      onMovePiece: _noopMove,
      onMoveNewPiece: _noop,
      currentUser: 'me',
      p1UserId: 'me',
      p2UserId: 'partner',
      p1Character: 'honggilldong',
      p2Character: 'miho',
      displayName: _previewName,
      coins: 50000,
    );
  }

  static void _noop() {}

  static void _noopMove(int _, int _, {int? backdoDir}) {}

  static String _previewName(String id) => id == 'me' ? '윷놀이마스터' : '송부사';
}
