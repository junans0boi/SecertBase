import 'package:flutter/material.dart';

class BombBoard extends StatelessWidget {
  final String? gameId;
  final String? holder;
  final int? timer;
  final VoidCallback onNewGame;
  final String currentUser;

  const BombBoard({
    super.key,
    this.gameId,
    this.holder,
    this.timer,
    required this.onNewGame,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final isMyTurn = holder == currentUser;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '폭탄 돌리기',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (gameId == null)
              ElevatedButton.icon(
                onPressed: onNewGame,
                icon: const Icon(Icons.play_arrow),
                label: const Text('새 게임 시작'),
              )
            else ...[
              Text(
                '폭탄 홀더: $holder ${isMyTurn ? "(내 폭탄!)" : ""}',
                style: TextStyle(
                  fontSize: 16,
                  color: isMyTurn ? Colors.red : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  '${timer ?? 0} 초',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isMyTurn)
                const Text(
                  '빨리 퀴즈를 풀고 패스하세요! (UI 연동 예정)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
