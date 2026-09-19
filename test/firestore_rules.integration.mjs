import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(localhost|127\.0\.0\.1):\d+$/.test(host)) throw Error('A local Firestore emulator is required; never run against production.');
const project = 'demo-flixie-review';
const root = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const token = uid => [
  { alg: 'none', typ: 'JWT' },
  { sub: uid, user_id: uid, aud: project, iss: `https://securetoken.google.com/${project}`, iat: Math.floor(Date.now()/1000), exp: Math.floor(Date.now()/1000)+3600, firebase: { sign_in_provider: 'custom', identities: {} } }
].map(v => Buffer.from(JSON.stringify(v)).toString('base64url')).join('.') + '.';
async function request(method, path, uid, body) {
  const response = await fetch(`${root}/${path}`, {
    method, headers: { 'Content-Type': 'application/json', ...(uid ? { Authorization: `Bearer ${uid === 'owner-admin' ? 'owner' : token(uid)}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {})
  });
  return response;
}
const string = value => ({ stringValue: value });
for (const [path, fields] of [
  ['userIdentities/auth-alice', { userId: string('db-alice') }],
  ['userIdentities/auth-bob', { userId: string('db-bob') }],
  ['userIdentities/auth-outsider', { userId: string('db-outsider') }],
  ['conversations/private', { memberIds: { arrayValue: { values: [string('db-alice'), string('db-bob')] } } }],
  ['conversations/private/messages/message', { text: string('Private message') }],
  ['conversations/private/members/db-alice', { userId: string('db-alice') }],
  ['conversations/private/watchRequests/plan', { createdBy: string('db-alice') }],
  ['conversations/private/watchRequests/plan/responses/db-bob', { userId: string('db-bob') }]
]) assert.equal((await request('PATCH', path, 'owner-admin', { fields })).status, 200);

for (const path of ['conversations/private', 'conversations/private/messages/message', 'conversations/private/members/db-alice', 'conversations/private/watchRequests/plan', 'conversations/private/watchRequests/plan/responses/db-bob']) {
  assert.equal((await request('GET', path, 'auth-alice')).status, 200, `member: ${path}`);
  assert.equal((await request('GET', path, 'auth-outsider')).status, 403, `outsider: ${path}`);
  assert.equal((await request('GET', path, null)).status, 403, `anonymous: ${path}`);
  assert.equal((await request('PATCH', path, 'auth-alice', { fields: { text: string('forged') } })).status, 403, `client write: ${path}`);
}
assert.equal((await request('GET', 'conversations', 'auth-outsider')).status, 403);
// Firestore rules are not filters: the real app's constrained query must work,
// while a forged member constraint and an unbounded query must fail.
async function query(uid, member) {
  const response = await fetch(`${root}:runQuery`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token(uid)}` },
    body: JSON.stringify({ structuredQuery: { from: [{ collectionId: 'conversations' }],
      ...(member ? { where: { fieldFilter: { field: { fieldPath: 'memberIds' }, op: 'ARRAY_CONTAINS', value: string(member) } } } : {}) } })
  });
  return response;
}
const ownQuery = await query('auth-alice', 'db-alice');
assert.equal(ownQuery.status, 200);
assert.equal((await ownQuery.json()).filter(item => item.document).length, 1);
assert.equal((await query('auth-outsider', 'db-alice')).status, 403);
assert.equal((await query('auth-alice')).status, 403);
assert.equal((await request('GET', 'conversations/private', 'auth-unmapped')).status, 403);
assert.equal((await request('GET', 'userIdentities/auth-alice', 'auth-alice')).status, 403);
assert.equal((await request('PATCH', 'userIdentities/auth-outsider', 'auth-outsider', { fields: { userId: string('db-alice') } })).status, 403);
await request('PATCH', 'accountDeletions/auth-alice', 'owner-admin', { fields: { userId: string('db-alice') } });
assert.equal((await request('GET', 'conversations/private', 'auth-alice')).status, 403);
assert.equal(readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'), readFileSync(new URL('../../FlixieBE/firestore.rules', import.meta.url), 'utf8'));
console.log('Firestore membership, deletion, forgery, listing and write protections passed.');
