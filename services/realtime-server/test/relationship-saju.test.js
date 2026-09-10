import assert from 'node:assert/strict';
import test from 'node:test';
import {
  buildRelationshipSaju,
  calculatePersonalSaju,
  getSajuProfileState,
} from '../src/relationship-saju.js';

const profile = (overrides = {}) => ({
  calendarType: 'solar',
  birthDate: '1995-03-16',
  lunarLeapMonth: false,
  birthTime: '07:30',
  timezone: 'Asia/Seoul',
  birthPlace: '서울특별시',
  ...overrides,
});

test('Saju wrapper locks the 입춘 instant boundary and returns the day pillar', () => {
  const beforeIpchun = calculatePersonalSaju({
    profile: profile({ birthDate: '2024-02-04', birthTime: '04:00' }),
  });
  const afterIpchun = calculatePersonalSaju({
    profile: profile({ birthDate: '2024-02-04', birthTime: '18:00' }),
  });

  assert.equal(beforeIpchun.technical.chart.year.hanja, '癸卯');
  assert.equal(afterIpchun.technical.chart.year.hanja, '甲辰');
  assert.equal(beforeIpchun.technical.chart.solarTermAdjusted, true);
  assert.equal(beforeIpchun.technical.chart.day.hanja, '戊戌');
});

test('Saju wrapper preserves the 00:29, 00:30, and late 자시 clock boundary inputs', () => {
  const at0029 = calculatePersonalSaju({
    profile: profile({ birthDate: '2000-05-15', birthTime: '00:29' }),
  });
  const at0030 = calculatePersonalSaju({
    profile: profile({ birthDate: '2000-05-15', birthTime: '00:30' }),
  });
  const at2330 = calculatePersonalSaju({
    profile: profile({ birthDate: '2000-05-15', birthTime: '23:30' }),
  });

  assert.equal(at0029.technical.chart.day.hanja, '癸酉');
  assert.equal(at0030.technical.chart.day.hanja, '癸酉');
  assert.equal(at0029.technical.chart.hour.hanja, '壬子');
  assert.equal(at0030.technical.chart.hour.hanja, '壬子');
  assert.equal(at2330.technical.chart.hour.hanja, '甲子');
});

test('Saju wrapper passes an explicit lunar leap-month flag to the engine', () => {
  const regular = calculatePersonalSaju({
    profile: profile({
      calendarType: 'lunar',
      birthDate: '2020-04-15',
      lunarLeapMonth: false,
      birthTime: '09:00',
    }),
  });
  const leap = calculatePersonalSaju({
    profile: profile({
      calendarType: 'lunar',
      birthDate: '2020-04-15',
      lunarLeapMonth: true,
      birthTime: '09:00',
    }),
  });

  assert.equal(regular.technical.chart.day.hanja, '庚戌');
  assert.equal(leap.technical.chart.day.hanja, '庚辰');
  assert.equal(leap.inputSummary.lunarLeapMonth, true);
});

test('Saju wrapper reports missing optional data, timezone limits, and supported range', () => {
  const limited = getSajuProfileState(profile({ birthTime: null, birthPlace: null }));
  assert.equal(limited.status, 'limited_available');
  assert.deepEqual(limited.limitations, ['birthTimeMissing', 'birthPlaceMissing']);

  const foreign = getSajuProfileState(profile({ timezone: 'America/New_York' }));
  assert.equal(foreign.status, 'limited_available');
  assert.ok(foreign.limitations.includes('timezoneLimited'));

  const unsupported = getSajuProfileState(profile({ birthDate: '1899-12-31' }));
  assert.equal(unsupported.status, 'unsupported_range');
});

test('limited mode keeps a known birth time while marking the missing place', () => {
  const result = calculatePersonalSaju({
    profile: profile({ birthPlace: null }),
    mode: 'limited',
  });
  assert.equal(result.status, 'limited');
  assert.equal(result.technical.chart.timeKnown, true);
  assert.ok(result.limitations.includes('birthPlaceMissing'));
});

test('personal Saju plain reading exposes a full, readable chart overview', () => {
  const result = calculatePersonalSaju({ profile: profile() });

  assert.equal(result.plain.pillars.length, 4);
  assert.deepEqual(result.plain.pillars.map((pillar) => pillar.key), [
    'year',
    'month',
    'day',
    'hour',
  ]);
  assert.ok(result.plain.pillars.every((pillar) => pillar.hanja && pillar.korean));
  assert.equal(result.plain.elements.entries.length, 5);
  assert.deepEqual(
    result.plain.elements.entries.map((entry) => entry.key),
    ['木', '火', '土', '金', '水'],
  );
  assert.equal(result.plain.sipseong.entries.length, 5);
  assert.ok(result.plain.dayMaster.label.includes(result.plain.dayMaster.stem));
  assert.ok(result.plain.dayMaster.summary.length > 20);
  assert.ok(result.plain.ilju.summary.length > 20);
  assert.equal(result.plain.disclaimer.includes('예측'), true);
});

test('relationship Saju returns pattern cards and questions without scores or raw partner charts', () => {
  const result = buildRelationshipSaju({
    firstProfile: profile({ birthDate: '1995-03-16' }),
    secondProfile: profile({
      birthDate: '1990-08-12',
      birthTime: '18:20',
      birthPlace: '부산광역시',
    }),
  });

  assert.equal(result.scope, 'couple');
  assert.equal(result.status, 'ready');
  assert.ok(result.patterns.length >= 2);
  assert.ok(result.conversationQuestions.length >= 2);
  assert.equal('score' in result, false);
  assert.equal('technical' in result, false);
  assert.equal('partnerChart' in result, false);
  assert.equal(result.patterns.every((pattern) => !('score' in pattern)), true);
});

test('relationship Saju marks missing partner input as limited without exposing partner data', () => {
  const result = buildRelationshipSaju({
    firstProfile: profile(),
    secondProfile: profile({ birthTime: null, birthPlace: null }),
    mode: 'limited',
  });

  assert.equal(result.scope, 'couple');
  assert.equal(result.status, 'limited');
  assert.ok(result.limitations.includes('secondBirthTimeMissing'));
  assert.ok(result.limitations.includes('secondBirthPlaceMissing'));
  assert.equal('technical' in result, false);
});
