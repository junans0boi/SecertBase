// 쪽지 실시간: 사용자별 방(note-user:<id>)으로만 보낸다. 연결은 JWT로 인증된 소켓만 들어오고,
// 받는 사람은 전송 시점의 활성 Couple 상대로 서버가 정한다.
let currentIo = null;

export const userRoom = (userId) => `note-user:${Number(userId)}`;

export function attachNotesRealtime(io) {
  currentIo = io;
  io.on('connection', (socket) => {
    const userId = Number(socket.data?.numericUserId);
    if (Number.isInteger(userId) && userId > 0) socket.join(userRoom(userId));
  });
}

export function createNotesPublisher(getIo = () => currentIo) {
  return (userId, event, payload) => {
    getIo()?.to(userRoom(userId)).emit(event, payload);
  };
}

export const publishNotesEvent = createNotesPublisher();
