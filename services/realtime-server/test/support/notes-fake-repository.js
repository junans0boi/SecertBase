// 쪽지 모듈 테스트용 메모리 저장소. 실제 SQL의 가림 규칙은 통합 테스트가 확인하고,
// 여기서는 raw 행(is_open 포함)을 돌려줘 서비스의 이중 가림을 검증한다.
export function createFakeNotesRepository({ couples, pins = [], posts = [], clock }) {
  const notes = [];
  let seq = 0;
  const isOpen = (n) => n.open_at === null || n.open_at.getTime() <= clock().getTime();
  const row = (n) => ({
    ...n,
    is_open: isOpen(n) ? 1 : 0,
    open_at_ts: n.open_at ? n.open_at.getTime() / 1000 : null,
    created_at_ts: n.created_at.getTime() / 1000,
    read_at_ts: n.read_at ? n.read_at.getTime() / 1000 : null,
    deleted_at: n.deleted_at ?? null,
  });
  return {
    notes,
    async resolveActiveCouple(userId) {
      return couples.find((c) => c.Status === 'active' && [c.User1Id, c.User2Id].includes(userId)) ?? null;
    },
    async findByClientRequest({ coupleId, userId, clientRequestId }) {
      const n = notes.find((x) => x.couple_id === coupleId && x.sender_id === userId
        && x.client_request_id === clientRequestId);
      return n ? row(n) : null;
    },
    async findMapPin(id) { return pins.find((p) => p.id === id) ?? null; },
    async findSetlogPost(id) { return posts.find((p) => p.id === id) ?? null; },
    async insertNote(args) {
      if (args.clientRequestId && notes.some((x) => x.sender_id === args.userId
        && x.client_request_id === args.clientRequestId)) {
        const error = new Error('dup'); error.code = 'ER_DUP_ENTRY'; throw error;
      }
      const n = {
        id: ++seq, couple_id: args.coupleId, sender_id: args.userId, body: args.body,
        media_url: args.mediaUrl, map_pin_id: args.mapPinId, setlog_post_id: args.setlogPostId,
        open_at: args.openAt, client_request_id: args.clientRequestId, created_at: clock(),
        delivered_at: null, read_at: null, reaction: null, deleted_at: null,
      };
      notes.push(n);
      return n.id;
    },
    async getNote({ coupleId, id }) {
      const n = notes.find((x) => x.id === id && x.couple_id === coupleId);
      return n ? row(n) : null;
    },
    async listNotes({ coupleId, before, limit }) {
      return notes.filter((n) => n.couple_id === coupleId && (!before || n.id < before))
        .sort((a, b) => b.id - a.id).slice(0, limit + 1).map(row);
    },
    async markRead({ coupleId, userId, upToId }) {
      let changed = 0;
      for (const n of notes) {
        if (n.couple_id === coupleId && n.sender_id !== userId && n.id <= upToId
          && !n.read_at && !n.deleted_at && isOpen(n)) { n.read_at = clock(); changed += 1; }
      }
      return changed;
    },
    async unreadCount({ coupleId, userId }) {
      return notes.filter((n) => n.couple_id === coupleId && n.sender_id !== userId
        && !n.read_at && !n.deleted_at && isOpen(n)).length;
    },
    async softDelete({ coupleId, id, userId }) {
      const n = notes.find((x) => x.id === id && x.couple_id === coupleId && x.sender_id === userId);
      if (!n || n.deleted_at) return n ? 0 : 0;
      Object.assign(n, { deleted_at: clock(), body: '', media_url: null });
      return 1;
    },
    async setReaction({ coupleId, id, emoji }) {
      const n = notes.find((x) => x.id === id && x.couple_id === coupleId);
      n.reaction = emoji;
    },
    async claimDelivery(id) {
      const n = notes.find((x) => x.id === id);
      if (!n || n.delivered_at || n.deleted_at || !isOpen(n)) return false;
      n.delivered_at = clock();
      return true;
    },
    // 예약 열람이 도래했고 아직 전달하지 않은 쪽지 + 현재 활성 Couple 정보.
    async listDueDeliveries() {
      const out = [];
      for (const n of notes) {
        if (n.delivered_at || n.deleted_at || !isOpen(n)) continue;
        const couple = couples.find((c) => c.CoupleId === n.couple_id && c.Status === 'active');
        if (!couple) continue;
        out.push({ id: n.id, couple_id: n.couple_id, sender_id: n.sender_id,
          recipient_id: couple.User1Id === n.sender_id ? couple.User2Id : couple.User1Id });
      }
      return out;
    },
  };
}
