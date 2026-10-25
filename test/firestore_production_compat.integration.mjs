// Run only against an emulator loaded with firestore.production-compat.rules.
import assert from 'node:assert/strict';
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(localhost|127\.0\.0\.1):\d+$/.test(host)) throw Error('Local Firestore emulator required');
const project = `demo-unread-${process.pid}`;
const root = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const string = stringValue => ({stringValue});
const integer = value => ({integerValue:String(value)});
const arr = values => ({arrayValue:{values:values.map(string)}});
function token(uid) {return [{alg:'none',typ:'JWT'},{sub:uid,user_id:uid,aud:project,iss:`https://securetoken.google.com/${project}`,iat:Math.floor(Date.now()/1000),exp:Math.floor(Date.now()/1000)+3600,firebase:{sign_in_provider:'custom',identities:{}}}].map(v=>Buffer.from(JSON.stringify(v)).toString('base64url')).join('.')+'.';}
async function call(path, method, uid, body) {
 const res=await fetch(root+path,{method,headers:{'content-type':'application/json',...(uid?{authorization:`Bearer ${uid==='owner'?'owner':token(uid)}`}:{})},...(body?{body:JSON.stringify(body)}:{})});
 return res;
}
async function set(path,fields) {assert.equal((await call('/'+path,'PATCH','owner',{fields})).status,200);}
function queryBody(user, positive=true) {
 const filters=[];
 if(user)filters.push({fieldFilter:{field:{fieldPath:'userId'},op:'EQUAL',value:string(user)}});
 if(positive)filters.push({fieldFilter:{field:{fieldPath:'unreadCount'},op:'GREATER_THAN',value:integer(0)}});
 return {structuredQuery:{from:[{collectionId:'members',allDescendants:true}],...(filters.length?{where:filters.length===1?filters[0]:{compositeFilter:{op:'AND',filters}}}:{})}};
}
async function own() {
 const res=await call(':runQuery','POST','alice',queryBody('db-alice'));
 assert.equal(res.status,200,await res.clone().text());
 return (await res.json()).filter(row=>row.document).map(row=>row.document);
}
await set('userIdentities/alice',{userId:string('db-alice')});
await set('userIdentities/bob',{userId:string('db-bob')});
for(let i=0;i<100;i++) {
 await set(`conversations/c${i}`,{memberIds:arr(['db-alice','db-bob']),lastMessageAt:{timestampValue:'2026-10-21T12:00:00Z'}});
 await set(`conversations/c${i}/members/db-alice`,{userId:string('db-alice'),unreadCount:integer(i<3?i+1:0)});
 await set(`conversations/c${i}/members/db-bob`,{userId:string('db-bob'),unreadCount:integer(9)});
}
let docs=await own();assert.equal(docs.length,3);assert.equal(docs.reduce((n,d)=>n+Number(d.fields.unreadCount.integerValue),0),6);
for(const [uid,body] of [[null,queryBody('db-alice')],['unmapped',queryBody('db-alice')],['bob',queryBody('db-alice')],['alice',queryBody(null)],['alice',queryBody('db-alice',false)]]) {
 assert.equal((await call(':runQuery','POST',uid,body)).status,403);
}
assert.equal((await call('/conversations/c3/members/forged','PATCH','alice',{fields:{userId:string('db-alice'),unreadCount:integer(10)}})).status,403);
// Existing unread writes are enough: no new summary document or fan-out.
await set('conversations/c1/members/db-alice',{userId:string('db-alice'),unreadCount:integer(0)});
assert.equal((await own()).length,2);
await set('conversations/c4/members/db-alice',{userId:string('db-alice'),unreadCount:integer(1)});
assert.equal((await own()).length,3);
// Production membership removal deletes member + updates parent atomically.
const removed=await call(':commit','POST','owner',{writes:[
 {delete:`projects/${project}/databases/(default)/documents/conversations/c0/members/db-alice`},
 {update:{name:`projects/${project}/databases/(default)/documents/conversations/c0`,fields:{memberIds:arr(['db-bob'])}},updateMask:{fieldPaths:['memberIds']}},
]});assert.equal(removed.status,200);
assert.equal((await own()).length,2);
assert.equal((await call('/conversations/c0','GET','alice')).status,200); // Legacy production grant retained.
assert.equal((await call('/conversations/c0/members/db-bob','GET','alice')).status,200); // Legacy grant retained.
await set('accountDeletions/alice',{userId:string('db-alice')});
assert.equal((await call(':runQuery','POST','alice',queryBody('db-alice'))).status,403);
// Released builds must keep their existing reads without identity readiness.
for (const path of ['/conversations/c2', '/conversations/c2/members/db-alice']) {
 assert.equal((await call(path,'GET','old-unmapped-build')).status,200);
 assert.equal((await call(path,'GET',null)).status,403);
 assert.equal((await call(path,'PATCH','old-unmapped-build',{fields:{userId:string('forged')}})).status,403);
}
await set('conversations/c2/messages/m1',{text:string('Local fixture only'),createdAt:{timestampValue:'2026-10-21T12:00:00Z'}});
assert.equal((await call('/conversations/c2/messages/m1','GET','old-unmapped-build')).status,200);
for (const [parent, structuredQuery] of [
 ['', {from:[{collectionId:'conversations'}],where:{fieldFilter:{field:{fieldPath:'memberIds'},op:'ARRAY_CONTAINS',value:string('db-alice')}},orderBy:[{field:{fieldPath:'lastMessageAt'},direction:'DESCENDING'}]}],
 ['/conversations/c2', {from:[{collectionId:'messages'}],orderBy:[{field:{fieldPath:'createdAt'},direction:'DESCENDING'}],limit:50}],
]) {
 const res=await call(parent+':runQuery','POST','old-unmapped-build',{structuredQuery});
 assert.equal(res.status,200,await res.clone().text());
 assert.ok((await res.json()).some(row=>row.document),'legacy query returns fixture data');
}
assert.equal((await call('/userIdentities/alice','GET','alice')).status,403);
assert.equal((await call('/userIdentities/alice','PATCH','alice',{fields:{userId:string('forged')}})).status,403);
console.log('PASS: production compatibility rules preserve unmapped released-client conversation/message/member reads, deny anonymous reads and client writes; unread owner filtering, mark-read removal, arrivals, membership removal and account deletion pass.');
