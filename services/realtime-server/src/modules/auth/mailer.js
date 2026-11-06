// 메일 발송 어댑터. 실제 메일 서비스는 아직 정하지 않았으므로 교체 가능한 세 가지만 둔다.
//   none    : 발송 수단 없음 → send()가 MailUnavailableError를 던진다(앱은 mail_unavailable 안내).
//   log     : 개발용. 메일 내용을 서버 로그에 남기고 성공으로 본다(운영에서는 쓰지 않는다).
//   webhook : MAIL_WEBHOOK_URL로 {from,to,subject,text,html} JSON을 POST한다(메일 API 중계용).

export class MailUnavailableError extends Error {
  constructor(message = 'mail_unavailable') {
    super(message);
    this.code = 'mail_unavailable';
  }
}

export const resolveMailTransport = ({ MAIL_TRANSPORT, NODE_ENV, MAIL_WEBHOOK_URL } = {}) => {
  if (MAIL_TRANSPORT) return MAIL_TRANSPORT;
  if (MAIL_WEBHOOK_URL) return 'webhook';
  return NODE_ENV === 'development' ? 'log' : 'none';
};

export function createMailer({
  transport = 'none',
  webhookUrl = '',
  webhookToken = '',
  from = '비밀기지 <no-reply@secretbase.cloud>',
  fetchFn = globalThis.fetch,
  log = console,
  timeoutMs = 8000,
} = {}) {
  if (transport === 'log') {
    return {
      transport,
      available: true,
      async send({ to, subject, text }) {
        log.info?.(`[Mail:log] to=${to} subject=${subject}\n${text}`);
      },
    };
  }
  if (transport === 'webhook' && webhookUrl) {
    return {
      transport,
      available: true,
      async send({ to, subject, text, html }) {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), timeoutMs);
        try {
          const response = await fetchFn(webhookUrl, {
            method: 'POST',
            headers: {
              'content-type': 'application/json',
              ...(webhookToken ? { authorization: `Bearer ${webhookToken}` } : {}),
            },
            body: JSON.stringify({ from, to, subject, text, html }),
            signal: controller.signal,
          });
          if (!response.ok) throw new MailUnavailableError(`webhook_status_${response.status}`);
        } catch (error) {
          if (error instanceof MailUnavailableError) throw error;
          throw new MailUnavailableError('webhook_failed');
        } finally {
          clearTimeout(timer);
        }
      },
    };
  }
  return {
    transport: 'none',
    available: false,
    async send() {
      throw new MailUnavailableError();
    },
  };
}
