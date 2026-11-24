import { z } from 'zod';

// 프로필 이모지: 1~16자, 제어문자·미할당·개행 불가. 이모지의 ZWJ(Cf)와 변형 선택자는 허용한다.
const FORBIDDEN = /[\p{Cc}\p{Cs}\p{Co}\p{Cn}\p{Zl}\p{Zp}]/u;

export const profileEmojiSchema = z
  .string()
  .min(1)
  .max(16)
  .refine((value) => value.trim().length > 0 && !FORBIDDEN.test(value), {
    message: 'invalid_profile_emoji',
  });

/**
 * 소켓 한 연결당 간단한 슬라이딩 윈도우 제한. 허용이면 true.
 * heart:send 같은 가벼운 이벤트가 브로드캐스트 폭주에 쓰이지 않게 한다.
 */
export const createSocketRateLimiter = ({ limit = 10, windowMs = 10_000, now = Date.now } = {}) => {
  const hits = [];
  return () => {
    const current = now();
    while (hits.length > 0 && current - hits[0] >= windowMs) hits.shift();
    if (hits.length >= limit) return false;
    hits.push(current);
    return true;
  };
};
