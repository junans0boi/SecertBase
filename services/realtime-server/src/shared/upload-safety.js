// 업로드 확장자는 클라이언트가 보낸 MIME에서 직접 만들지 않고 화이트리스트에서만 정한다.
const EXTENSION_BY_MIME = new Map([
  ['image/jpeg', 'jpg'],
  ['image/png', 'png'],
  ['image/webp', 'webp'],
  ['image/gif', 'gif'],
  ['image/heic', 'heic'],
  ['image/heif', 'heif'],
  ['video/mp4', 'mp4'],
  ['video/quicktime', 'mov'],
  ['video/webm', 'webm'],
  ['audio/mpeg', 'mp3'],
  ['audio/mp4', 'm4a'],
  ['audio/x-m4a', 'm4a'],
  ['audio/aac', 'aac'],
  ['audio/wav', 'wav'],
  ['audio/x-wav', 'wav'],
  ['audio/ogg', 'ogg'],
  ['audio/webm', 'webm'],
  ['audio/3gpp', '3gp'],
  ['application/octet-stream', 'bin'],
]);

export const extensionForMime = (mime) =>
  EXTENSION_BY_MIME.get(String(mime ?? '').split(';')[0].trim().toLowerCase()) ?? null;

export const isAllowedUploadMime = (mime) => extensionForMime(mime) !== null;

// 서빙되는 업로드 파일이 브라우저에서 스크립트로 실행되지 않도록 하는 헤더.
export const setUploadResponseHeaders = (res) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; sandbox");
};
