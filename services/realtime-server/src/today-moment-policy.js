export const canReplaceTodayMoment = (revealedAt) => !revealedAt;

export function todayMomentStatus({ hasMine, hasPartner, viewed = false }) {
  if (hasMine && hasPartner) return viewed ? 'viewed' : 'complete';
  if (hasMine) return 'self_waiting';
  if (hasPartner) return 'partner_waiting';
  return 'empty';
}
