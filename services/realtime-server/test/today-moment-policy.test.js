import assert from 'node:assert/strict';
import test from 'node:test';
import {
  canReplaceTodayMoment,
  maskLockedTodayMoment,
  todayMomentStatus,
} from '../src/today-moment-policy.js';

test('a Today Moment can be replaced only before the Today Loop is revealed', () => {
  assert.equal(canReplaceTodayMoment(null), true);
  assert.equal(canReplaceTodayMoment('2026-07-29T10:00:00.000Z'), false);
});

test('maskLockedTodayMoment exposes only presence metadata to the waiting partner', () => {
  const masked = maskLockedTodayMoment({
    post: {
      id: 47,
      couple_id: 3,
      user_id: 10,
      UserName: 'Partner',
      media_type: 'image',
      media_url: '/uploads/private.png',
      caption: 'private caption',
      tags: '["private"]',
      taken_at: '2026-07-29',
      captured_at: '2026-07-29T12:34:56.000Z',
      map_pin_id: 99,
      linked_place_name: 'private place',
      session_id: 'private-session',
      session_reactions: '[{}]',
      today_business_date: '2026-07-29',
      today_revealed_at: null,
      viewer_today_moment_id: null,
    },
    viewerUserId: 11,
  });

  assert.deepEqual(masked, {
    id: 47,
    couple_id: 3,
    user_id: 10,
    UserName: 'Partner',
    taken_at: '2026-07-29',
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
  });
});

test('maskLockedTodayMoment preserves content for the author or a revealed loop', () => {
  const post = {
    id: 47,
    user_id: 10,
    caption: 'visible',
    today_business_date: '2026-07-29',
    today_revealed_at: null,
    viewer_today_moment_id: null,
  };
  assert.equal(maskLockedTodayMoment({ post, viewerUserId: 10 }).caption, 'visible');
  assert.equal(maskLockedTodayMoment({
    post: { ...post, today_revealed_at: '2026-07-29T12:00:00.000Z' },
    viewerUserId: 11,
  }).caption, 'visible');
});

test('todayMomentStatus describes the authenticated user perspective', () => {
  assert.equal(todayMomentStatus({ hasMine: false, hasPartner: false, viewed: false }), 'empty');
  assert.equal(todayMomentStatus({ hasMine: false, hasPartner: true, viewed: false }), 'partner_waiting');
  assert.equal(todayMomentStatus({ hasMine: true, hasPartner: false, viewed: false }), 'self_waiting');
  assert.equal(todayMomentStatus({ hasMine: true, hasPartner: true, viewed: false }), 'complete');
  assert.equal(todayMomentStatus({ hasMine: true, hasPartner: true, viewed: true }), 'viewed');
});
