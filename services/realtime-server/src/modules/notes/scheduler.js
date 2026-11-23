// 예약 열람 시각이 된 쪽지를 매분 전달(실시간 + 푸시)한다.
export function startNotesScheduler({ cron, service, log = console }) {
  return cron.schedule('* * * * *', async () => {
    try {
      await service.deliverDue();
    } catch {
      log.error('[Notes] scheduler failed');
    }
  }, { timezone: 'Asia/Seoul', noOverlap: true });
}
