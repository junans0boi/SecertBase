// 게임 모듈 레지스트리(게임 2.0). 게임마다 한 파일에서 소켓 핸들러·재대결·복원·잠수 감시를
// 정의하고 socket.js가 이 목록을 순회해 연결한다. 모듈 모양은 README 주석 참고:
//
//   export default {
//     gameType: 'blackjack',
//     register(socket, kit) {},              // 연결마다 소켓 이벤트 등록(안전망이 감싼다)
//     async restart(roomCode, kit, ctx) {},  // 동의된 재대결. ctx = { p1, p2, orderedPlayers }
//     async restore(roomCode, socket, kit) {}, // 재접속 소켓에 진행 중 상태를 다시 보냄 → true/false
//     afk(kit) { return { key, playersOf, waitingOn, forfeit } }, // game-afk.js 어댑터
//     dispose() {},                          // 서버 종료 시 타이머 정리
//   };
//
// kit(socket.js가 만든다): io, redis, timerApi, withRoomLock, normalizeAck, getPresence,
// getOrderedPlayers, consumePendingGame, recordGameOutcome, presenceProfiles,
// presenceNicknames, series, randomUUID.
import blackjack from "./blackjack.js";
import catchGame from "./catch.js";
import oldmaid from "./oldmaid.js";
import onecard from "./onecard.js";
import penalty from "./penalty.js";
import pirate from "./pirate.js";
import zero from "./zero.js";

export const GAME_MODULES = [blackjack, catchGame, oldmaid, onecard, penalty, pirate, zero].filter((m) => m && m.gameType);
