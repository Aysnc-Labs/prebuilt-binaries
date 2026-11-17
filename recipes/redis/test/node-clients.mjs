import assert from 'node:assert/strict';
import { Redis } from 'ioredis';
import { createClient, SCHEMA_FIELD_TYPE } from 'redis';
import { Queue, Worker } from 'bullmq';

const port = Number(process.env.REDIS_PORT);
const connection = { host: '127.0.0.1', port };

const io = new Redis(connection);
await io.set('ioredis', 'ok', 'EX', 60);
assert.equal(await io.get('ioredis'), 'ok');
console.log('ioredis: ok');

const client = createClient({ url: `redis://127.0.0.1:${port}` });
await client.connect();
const subscriber = client.duplicate();
await subscriber.connect();
const message = new Promise((resolve) => subscriber.subscribe('revalidate', resolve));
await new Promise((resolve) => setTimeout(resolve, 100));
await client.publish('revalidate', 'posts');
assert.equal(await message, 'posts');
await client.hSet('cache:page', { body: '<html>', tags: 'posts' });
assert.equal(await client.hGet('cache:page', 'body'), '<html>');
console.log('node-redis: ok');

await client.json.set('doc:1', '$', { title: 'Hello', tags: ['posts'], views: 3 });
assert.deepEqual(await client.json.get('doc:1', { path: '$.views' }), [3]);
await client.ft.create('idx:docs', {
  '$.title': { type: SCHEMA_FIELD_TYPE.TEXT, AS: 'title' },
  '$.tags[*]': { type: SCHEMA_FIELD_TYPE.TAG, AS: 'tags' },
}, { ON: 'JSON', PREFIX: 'doc:' });
const found = await client.ft.search('idx:docs', '@tags:{posts} hello');
assert.equal(found.total, 1);
assert.equal(found.documents[0].id, 'doc:1');
console.log('node-redis JSON and Search: ok');

const queue = new Queue('smoke', { connection });
const worker = new Worker('smoke', async (job) => job.data.n * 2, { connection });
const result = new Promise((resolve, reject) => {
  worker.on('completed', (_job, value) => resolve(value));
  worker.on('failed', (_job, error) => reject(error));
});
await queue.add('double', { n: 21 }, { delay: 200, attempts: 2 });
assert.equal(await result, 42);
console.log('bullmq: ok');

await Promise.all([worker.close(), queue.close()]);
await Promise.all([io.quit(), client.quit(), subscriber.quit()]);
