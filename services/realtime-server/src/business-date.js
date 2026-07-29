const KOREA_DATE_FORMAT = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Asia/Seoul',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

export function businessDate(value = new Date()) {
  const parts = Object.fromEntries(
    KOREA_DATE_FORMAT.formatToParts(value)
      .filter(({ type }) => type !== 'literal')
      .map(({ type, value: partValue }) => [type, partValue]),
  );
  return `${parts.year}-${parts.month}-${parts.day}`;
}

export function businessWeekStart(value = new Date()) {
  const date = businessDate(value);
  const utcDate = new Date(`${date}T00:00:00.000Z`);
  const daysSinceMonday = (utcDate.getUTCDay() + 6) % 7;
  utcDate.setUTCDate(utcDate.getUTCDate() - daysSinceMonday);
  return utcDate.toISOString().slice(0, 10);
}
