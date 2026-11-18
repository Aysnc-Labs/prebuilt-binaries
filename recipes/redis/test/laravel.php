<?php
$redis = new Redis();
$redis->connect('127.0.0.1', (int) getenv('REDIS_PORT'));

$redis->setex('laravel_cache:greeting', 60, serialize('hello'));
assert_same('hello', unserialize($redis->get('laravel_cache:greeting')), 'cache');

$push = <<<'LUA'
redis.call('rpush', KEYS[1], ARGV[1])
redis.call('rpush', KEYS[2], 1)
LUA;
$pop = <<<'LUA'
local job = redis.call('lpop', KEYS[1])
local reserved = false
if(job ~= false) then
    reserved = cjson.decode(job)
    reserved['attempts'] = reserved['attempts'] + 1
    reserved = cjson.encode(reserved)
    redis.call('zadd', KEYS[2], ARGV[1], reserved)
    redis.call('lpop', KEYS[3])
end
return {job, reserved}
LUA;
$payload = json_encode(['uuid' => 'a1', 'job' => 'SendEmail', 'attempts' => 0]);
$redis->eval($push, ['queues:default', 'queues:default:notify', $payload], 2);
[$job, $reserved] = $redis->eval($pop, ['queues:default', 'queues:default:reserved', 'queues:default:notify', time() + 90], 3);
assert_same($payload, $job, 'queue pop');
assert_same(1, json_decode($reserved, true)['attempts'], 'queue attempts');
assert_same(1, $redis->zCard('queues:default:reserved'), 'reserved set');

$redis->sAdd('tag:posts:entries', 'laravel_cache:post:1');
assert_same(['laravel_cache:post:1'], $redis->sMembers('tag:posts:entries'), 'cache tags');

echo "phpredis (Laravel cache and queue): ok\n";

function assert_same($expected, $actual, string $what): void
{
    if ($expected !== $actual) {
        fwrite(STDERR, "$what: expected " . var_export($expected, true) . ', got ' . var_export($actual, true) . "\n");
        exit(1);
    }
}
