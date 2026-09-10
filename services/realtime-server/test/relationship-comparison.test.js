import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CHANGE_COMPARISON_MESSAGE,
  buildAssessmentComparison,
} from '../src/relationship-comparison.js';

test('personal comparison uses recent same-version dimension deltas without labels', () => {
  const comparison = buildAssessmentComparison({
    scope: 'personal',
    assessmentCode: 'attachment',
    version: 'v1',
    records: [
      {
        id: 8,
        createdAt: '2026-09-10T00:00:00.000Z',
        result: {
          overallScore: 70,
          dimensions: [{ key: 'reassurance', title: '확인과 안심', score: 80 }],
        },
      },
      {
        id: 4,
        createdAt: '2026-08-10T00:00:00.000Z',
        result: {
          overallScore: 60,
          dimensions: [{ key: 'reassurance', title: '확인과 안심', score: 50 }],
        },
      },
    ],
  });
  assert.equal(comparison.status, 'ready');
  assert.equal(comparison.metric, 'dimensionScore');
  assert.equal(comparison.overall.delta, 10);
  assert.deepEqual(comparison.dimensions[0], {
    key: 'reassurance',
    title: '확인과 안심',
    previous: 50,
    current: 80,
    delta: 30,
  });
  assert.equal('tendency' in comparison, false);
  assert.equal(comparison.visualization, 'bar_or_line');
});

test('couple comparison keeps pair score primary and alignment as a separate value', () => {
  const comparison = buildAssessmentComparison({
    scope: 'couple',
    assessmentCode: 'conflict_repair',
    version: 'v1',
    records: [
      {
        id: 9,
        result: {
          overallScore: 62,
          overallAlignmentScore: 78,
          dimensions: [{ key: 'safety', title: '안전', pairScore: 62, alignmentScore: 78 }],
        },
      },
      {
        id: 5,
        result: {
          overallScore: 55,
          overallAlignmentScore: 70,
          dimensions: [{ key: 'safety', title: '안전', pairScore: 55, alignmentScore: 70 }],
        },
      },
    ],
  });
  assert.equal(comparison.metric, 'pairScore');
  assert.equal(comparison.overall.current, 62);
  assert.equal(comparison.overall.delta, 7);
  assert.deepEqual(comparison.dimensions[0].alignment, {
    previous: 70,
    current: 78,
    delta: 8,
  });
});

test('comparison gives a plain-language retry prompt with one record', () => {
  const comparison = buildAssessmentComparison({
    scope: 'personal',
    assessmentCode: 'attachment',
    version: 'v1',
    records: [{ id: 1, result: { overallScore: 50, dimensions: [] } }],
  });
  assert.equal(comparison.status, 'insufficient_data');
  assert.equal(comparison.available, false);
  assert.equal(comparison.message, CHANGE_COMPARISON_MESSAGE);
});
