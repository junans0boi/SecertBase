export const canReplaceTodayMoment = (revealedAt) => !revealedAt;

export const canViewTodayMoment = ({ isAuthor, revealed, viewerHasMoment }) =>
  Boolean(isAuthor || revealed || viewerHasMoment);

export function todayMomentStatus({ hasMine, hasPartner, viewed = false }) {
  if (hasMine && hasPartner) return viewed ? 'viewed' : 'complete';
  if (hasMine) return 'self_waiting';
  if (hasPartner) return 'partner_waiting';
  return 'empty';
}

export function maskLockedTodayMoment({ post, viewerUserId }) {
  if (!post?.today_business_date) return post;

  const {
    today_business_date: _businessDate,
    today_revealed_at: revealedAt,
    viewer_today_moment_id: viewerMomentId,
    ...publicPost
  } = post;
  const canView = canViewTodayMoment({
    isAuthor: Number(post.user_id) === Number(viewerUserId),
    revealed: Boolean(revealedAt),
    viewerHasMoment: Boolean(viewerMomentId),
  });
  if (canView) return { ...publicPost, today_locked: false };

  return {
    id: post.id,
    couple_id: post.couple_id,
    user_id: post.user_id,
    UserName: post.UserName,
    taken_at: post.taken_at,
    media_type: null,
    media_url: null,
    caption: null,
    tags: null,
    captured_at: null,
    map_pin_id: null,
    linked_place_name: null,
    session_id: null,
    session_reactions: null,
    today_locked: true,
  };
}
