import { createHash } from 'node:crypto';
import { clientIpKey, createRateLimiter } from '../shared/rate-limit.js';

// 기지 초대장: 링크 하나로 앱 열기·설치 안내.
// 코드 존재 여부를 알 수 없도록 모든 값에 byte 단위로 같은 페이지를 돌려준다.
// 코드는 서버가 아니라 브라우저 스크립트가 주소에서 읽어 앱 링크를 만든다.
// 초대자 닉네임 등 어떤 개인정보도 이 경로에서 조회하지 않는다.

const DEFAULT_PACKAGE = 'com.secretbase.secret_base_app';
const FINGERPRINT = /^([0-9A-F]{2}:){31}[0-9A-F]{2}$/;

const STYLE = `
body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#14121f;color:#f4f1ff;font-family:-apple-system,BlinkMacSystemFont,"Apple SD Gothic Neo","Noto Sans KR",sans-serif}
main{max-width:360px;padding:32px 24px;text-align:center}
h1{font-size:24px;margin:0 0 12px}
p{line-height:1.6;color:#cfc9e8;margin:0 0 16px}
a.btn{display:block;padding:14px 16px;border-radius:14px;background:#8b7cf6;color:#fff;font-weight:700;text-decoration:none}
small{display:block;margin-top:20px;color:#9a93bd;line-height:1.5}
`;

const SCRIPT = `
(function(){
  var m=location.pathname.match(/^\\/i\\/([A-Za-z0-9]{6})\\/?$/);
  var a=document.getElementById('open');
  if(m){a.href='secretbase://invite/'+m[1].toUpperCase();}
  else{a.style.display='none';}
})();
`;

const sha = text => `'sha256-${createHash('sha256').update(text).digest('base64')}'`;

export const LANDING_CSP = [
  "default-src 'none'",
  `style-src ${sha(STYLE)}`,
  `script-src ${sha(SCRIPT)}`,
  "base-uri 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
].join('; ');

export const LANDING_HTML = `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>기지 초대장 · 비밀기지</title>
<style>${STYLE}</style>
</head>
<body>
<main>
<h1>기지 초대장이 도착했어요</h1>
<p>누군가 비밀기지에서 둘만의 공간을 함께 열고 싶어 해요. 앱에서 확인한 뒤 직접 연결을 정할 수 있어요.</p>
<a id="open" class="btn" href="secretbase://invite/">비밀기지 앱에서 열기</a>
<small>앱이 아직 없다면 비밀기지를 설치한 뒤 이 링크를 한 번 더 눌러 주세요. 연결은 앱에서 확인하기 전까지 시작되지 않아요.</small>
</main>
<script>${SCRIPT}</script>
</body>
</html>
`;

export function parseFingerprints(raw) {
  return String(raw ?? '')
    .split(',')
    .map(item => item.trim().toUpperCase())
    .filter(item => FINGERPRINT.test(item));
}

export function registerBaseInvite(app, config = {}) {
  const limiter = createRateLimiter({
    windowMs: 60_000,
    max: Number.isInteger(config.BASE_INVITE_RATE_MAX) ? config.BASE_INVITE_RATE_MAX : 30,
    keyFn: clientIpKey('base-invite'),
  });

  app.get('/i/:code', limiter, (_, res) => {
    res.set({
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
      'X-Robots-Tag': 'noindex, nofollow',
      'Content-Security-Policy': LANDING_CSP,
    });
    res.status(200).send(LANDING_HTML);
  });

  // 값(키스토어 SHA-256)은 환경 변수에서만 온다. 비어 있으면 빈 배열이다.
  app.get('/.well-known/assetlinks.json', (_, res) => {
    const fingerprints = parseFingerprints(config.ANDROID_APP_LINK_SHA256 ?? process.env.ANDROID_APP_LINK_SHA256);
    const packageName = config.ANDROID_PACKAGE_NAME || process.env.ANDROID_PACKAGE_NAME || DEFAULT_PACKAGE;
    res.set('Cache-Control', 'public, max-age=300');
    res.json(fingerprints.length === 0 ? [] : [{
      relation: ['delegate_permission/common.handle_all_urls'],
      target: {
        namespace: 'android_app',
        package_name: packageName,
        sha256_cert_fingerprints: fingerprints,
      },
    }]);
  });
}
