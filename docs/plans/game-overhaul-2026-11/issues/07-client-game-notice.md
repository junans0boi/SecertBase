# 07: 클라이언트 거부 사유 안내

**What to build:** 서버가 게임 액션을 거부하면 사용자는 짧은 한국어 안내를 SnackBar로 본다.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] SocketService._emitGame(event, payload) + 사유→문구 매핑 + gameNotice
- [ ] GameMenuListener/GameScaffold에서 SnackBar 표시
- [ ] 주요 게임 start/액션 emit 전환
