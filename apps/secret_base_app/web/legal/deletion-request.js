// Populate only after the owner verifies the deletion-request mailbox.
// The existing app contact label is not evidence of verified ownership/receipt.
export const verifiedOperatorEmail = '';

const emailPattern = /^[^\s@<>;,?:]+@[^\s@<>;,?:]+\.[^\s@<>;,?:]+$/;

export function buildDeletionMailto(accountEmail, operatorEmail = verifiedOperatorEmail) {
  const account = accountEmail.trim();
  if (!emailPattern.test(account) || !emailPattern.test(operatorEmail)) return null;
  const subject = 'Secret Base 계정 삭제 요청';
  const body = [
    'Secret Base 계정 및 관련 개인정보 삭제를 요청합니다.',
    '가입 이메일: ' + account,
    '',
    '본인 확인 방법과 삭제되는 정보, 보관되는 정보 및 처리 기한을 안내해 주세요.',
    '비밀번호와 인증 코드는 이메일로 보내지 않습니다.',
  ].join('\n');
  return 'mailto:' + encodeURIComponent(operatorEmail).replace('%40', '@') +
    '?subject=' + encodeURIComponent(subject) + '&body=' + encodeURIComponent(body);
}

export function setupDeletionRequest({
  document,
  operatorEmail = verifiedOperatorEmail,
  navigate,
}) {
  const form = document.getElementById('deletion-form');
  const email = document.getElementById('account-email');
  const button = document.getElementById('send-request');
  const status = document.getElementById('request-status');
  if (!form || !email || !button || !status) return;
  button.disabled = !emailPattern.test(operatorEmail);
  status.textContent = button.disabled
    ? '삭제 요청 수신 이메일 미확인 — 이메일 접수 준비 중입니다.'
    : '메일 앱에서 내용을 확인하고 직접 전송해 주세요.';
  form.addEventListener('submit', event => {
    event.preventDefault();
    if (button.disabled || !form.reportValidity()) return;
    const mailto = buildDeletionMailto(email.value, operatorEmail);
    if (!mailto) return;
    navigate(mailto);
    status.textContent = '메일 앱에서 전송을 완료해야 요청이 접수됩니다.';
  });
}

if (typeof document !== 'undefined') {
  setupDeletionRequest({ document, navigate: url => window.location.assign(url) });
}
