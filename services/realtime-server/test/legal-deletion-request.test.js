import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const script = new URL('../../../apps/secret_base_app/web/legal/deletion-request.js', import.meta.url);

test('deletion request opens a mail draft with the account email, never auto-sends', async () => {
  const { buildDeletionMailto } = await import(script);
  const result = buildDeletionMailto('member+tag@example.test', 'operator@example.test');
  const url = new URL(result);
  assert.equal(url.protocol, 'mailto:');
  assert.equal(url.pathname, 'operator@example.test');
  assert.equal(url.searchParams.get('subject'), 'Secret Base 계정 삭제 요청');
  assert.ok(url.searchParams.get('body').includes('member+tag@example.test'));
  assert.ok(url.searchParams.get('body').includes('계정 및 관련 개인정보 삭제'));
  assert.equal(url.searchParams.get('cc'), null);
});

test('deletion request rejects invalid email and a missing verified operator contact', async () => {
  const { buildDeletionMailto } = await import(script);
  assert.equal(buildDeletionMailto('member@example.test'), null);
  for (const address of ['', 'missing-at', 'member@example.test\r\nBcc:other@example.test']) {
    assert.equal(buildDeletionMailto(address, 'operator@example.test'), null);
  }
});

test('email form submission navigates to mailto only when contact is configured', async () => {
  const { setupDeletionRequest } = await import(script);
  let submit;
  const form = { addEventListener: (_, handler) => { submit = handler; }, reportValidity: () => true };
  const email = { value: 'member@example.test' };
  const button = {};
  const status = {};
  const document = { getElementById: id => ({ 'deletion-form': form, 'account-email': email, 'send-request': button, 'request-status': status })[id] };
  const navigations = [];
  setupDeletionRequest({ document, navigate: url => navigations.push(url) });
  assert.equal(button.disabled, true);
  submit({ preventDefault() {} });
  assert.deepEqual(navigations, []);
  assert.ok(status.textContent.includes('미확인'));

  setupDeletionRequest({ document, operatorEmail: 'operator@example.test', navigate: url => navigations.push(url) });
  assert.equal(button.disabled, false);
  submit({ preventDefault() {} });
  assert.equal(navigations.length, 1);
  assert.ok(navigations[0].startsWith('mailto:operator@example.test?'));
});

test('deletion page has a labeled email field, app path and pending review notice', async () => {
  const html = await readFile(new URL('../../../apps/secret_base_app/web/delete-account/index.html', import.meta.url), 'utf8');
  assert.match(html, /<label for="account-email">/);
  assert.match(html, /type="email"[^>]*required/);
  assert.ok(html.includes('삭제 요청 이메일 보내기'));
  assert.ok(html.includes('더보기 → 내 공간 → 회원 탈퇴'));
  assert.ok(html.includes('법률 검토 미완료'));
  assert.ok(html.includes('미확인'));
});
