const { test } = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const CleanupService = require('../modules/cleanup/cleanup_service');
const FakeFirestore = require('./helpers/fake_firestore');

const ts = (iso) => admin.firestore.Timestamp.fromDate(new Date(iso));

test('古い雲を消す前に、見えた記録へ雲が見えていた時間を写す', async () => {
  const firestore = new FakeFirestore();
  firestore.docs.set('clouds/old', {
    status: 'ended', firstSeenAt: ts('2026-08-12T05:20:00Z'), lastSeenAt: ts('2026-08-12T06:40:00Z'),
  });
  firestore.docs.set('clouds/recent', {
    status: 'ended', firstSeenAt: ts('2026-08-14T05:00:00Z'), lastSeenAt: ts('2026-08-14T06:00:00Z'),
  });
  firestore.docs.set('reports/r1', { uid: 'u1', cloudId: 'old', seen: true });
  firestore.docs.set('reports/r2', { uid: 'u2', cloudId: 'recent', seen: true });

  const service = new CleanupService();
  Object.defineProperty(service, 'firestore', { get: () => firestore });
  const deleted = await service.cleanupOldClouds(new Date('2026-08-16T00:00:00Z'));

  assert.equal(deleted, 1);
  assert.equal(firestore.docs.has('clouds/old'), false);
  assert.equal(firestore.docs.has('clouds/recent'), true);
  const r1 = firestore.docs.get('reports/r1');
  assert.equal(r1.cloudFirstSeenAt.toDate().toISOString(), '2026-08-12T05:20:00.000Z');
  assert.equal(r1.cloudLastSeenAt.toDate().toISOString(), '2026-08-12T06:40:00.000Z');
  assert.equal(firestore.docs.get('reports/r2').cloudFirstSeenAt, undefined);
});
