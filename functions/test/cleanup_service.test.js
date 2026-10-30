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

test('1年開いていない利用者の情報を消す。Plus の期間が残っている人と、最近開いた人は消さない', async () => {
  const firestore = new FakeFirestore();
  const old = ts('2025-08-01T00:00:00Z');
  firestore.docs.set('members/gone', { lastOpenedAt: old });
  firestore.docs.set('member_server/gone', { notification: {} });
  firestore.docs.set('reports/g1', { uid: 'gone', seen: true });
  firestore.docs.set('members/paying', { lastOpenedAt: old });
  firestore.docs.set('member_server/paying', { isPlus: true, plusExpiresAt: ts('2027-01-01T00:00:00Z') });
  firestore.docs.set('members/active', { lastOpenedAt: ts('2026-08-01T00:00:00Z') });

  const service = new CleanupService();
  Object.defineProperty(service, 'firestore', { get: () => firestore });
  const deleted = await service.cleanupInactiveMembers(new Date('2026-10-21T00:00:00Z'));

  assert.equal(deleted, 1);
  assert.equal(firestore.docs.has('members/gone'), false);
  assert.equal(firestore.docs.has('member_server/gone'), false);
  assert.equal(firestore.docs.has('reports/g1'), false);
  assert.equal(firestore.docs.has('members/paying'), true);
  assert.equal(firestore.docs.has('members/active'), true);
});
