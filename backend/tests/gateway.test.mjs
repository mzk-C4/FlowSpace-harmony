import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { createGateway } from '../server.mjs';
import { validateDocument, validateRequest, validateCandidate } from '../validation.mjs';
import { readConfig } from '../llm.mjs';

const clone = value => structuredClone(value);
function document() {
  return { schemaVersion: 1, documentId: 'map_test', title: '工科知识', revision: 3, rootId: 'root',
    nodes: [{ id: 'root', parentId: '', order: 0, text: '工科知识', note: '', collapsed: false },
      { id: 'branch', parentId: 'root', order: 0, text: '电路', note: '', collapsed: false },
      { id: 'outside', parentId: 'root', order: 1, text: '数学', note: '', collapsed: false }],
    layout: 'right', sourceText: '电路和数学', messages: [], createdAt: '2026-11-03T00:00:00.000Z', updatedAt: '2026-11-03T00:00:00.000Z' };
}
function request(mode = 'create', id = 'request_test') {
  const doc = document();
  return { requestId: id, documentId: doc.documentId, baseRevision: doc.revision, mode, instruction: '整理知识点', scopeNodeId: mode === 'revise' ? 'branch' : '', document: doc, messages: [] };
}
function result(req = request()) { return { document: clone(req.document), summary: '已整理知识结构' }; }
async function listen(server) {
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  return `http://127.0.0.1:${server.address().port}`;
}
async function close(server) {
  server.closeAllConnections(); await new Promise(resolve => server.close(resolve));
}
async function setup(t, handler, options = {}) {
  let calls = 0;
  const upstream = createServer(async (req, res) => {
    let body = ''; for await (const chunk of req) body += chunk;
    const payload = JSON.parse(body);
    calls++;
    assert.equal(payload.stream, true);
    assert.equal(req.headers.authorization, 'Bearer fake-test-key');
    await handler(req, res, payload, calls);
  });
  const upstreamUrl = await listen(upstream);
  const gateway = createGateway({ env: { LLM_BASE_URL: `${upstreamUrl}/v1`, LLM_MODEL: 'test-model', LLM_API_KEY: 'fake-test-key' }, ...options });
  const url = await listen(gateway);
  t.after(async () => { await close(gateway); await close(upstream); });
  return { url, calls: () => calls };
}
async function emit(res, output, split = false) {
  res.writeHead(200, { 'Content-Type': 'text/event-stream' });
  const value = typeof output === 'string' ? output : JSON.stringify(output);
  const frame = `data: ${JSON.stringify({ choices: [{ delta: { content: value, reasoning_content: 'HIDDEN_REASONING' } }] })}\r\n\r\ndata: [DONE]\r\n\r\n`;
  if (split) {
    const bytes = Buffer.from(frame);
    for (let i = 0; i < bytes.length; i += 7) {
      res.write(bytes.subarray(i, i + 7));
      await new Promise(resolve => setImmediate(resolve));
    }
  } else res.write(frame);
  res.end();
}
const post = (url, payload, options = {}) => fetch(`${url}/api/mindmaps/generate`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload), ...options
});
const events = text => text.trim().split('\n\n').map(line => JSON.parse(line.slice(6)));

test('configuration supports v1 root and complete endpoint; rejects unsafe URLs', () => {
  const env = { LLM_BASE_URL: 'https://example.com/v1/', LLM_MODEL: 'model', LLM_API_KEY: 'secret' };
  assert.equal(readConfig(env).endpoint, 'https://example.com/v1/chat/completions');
  assert.equal(readConfig({ ...env, LLM_BASE_URL: 'https://example.com/v1/chat/completions' }).endpoint, 'https://example.com/v1/chat/completions');
  assert.equal(readConfig({ ...env, LLM_BASE_URL: 'file:///secret' }).configured, false);
  assert.equal(readConfig({}).configured, false);
});

test('graph and request validation reject cycles, duplicate/orphan IDs, depth, oversized input and wrong revision', () => {
  for (const mutate of [
    d => d.nodes.push(clone(d.nodes[1])),
    d => d.nodes[1].parentId = 'missing',
    d => { d.nodes[1].parentId = 'outside'; d.nodes[2].parentId = 'branch'; },
    d => d.nodes[0].parentId = 'branch',
    d => d.nodes[1].order = -1
  ]) { const doc = document(); mutate(doc); assert.throws(() => validateDocument(doc)); }
  const deep = document();
  for (let i = 0; i < 8; i++) deep.nodes.push({ ...deep.nodes[1], id: `n${i}`, parentId: i ? `n${i - 1}` : 'branch' });
  assert.throws(() => validateDocument(deep), /8 层/);
  assert.throws(() => validateRequest({ ...request(), instruction: 'a'.repeat(20001) }));
  assert.throws(() => validateRequest({ ...request(), baseRevision: 1 }), /baseRevision/);
  assert.throws(() => validateRequest({ ...request('revise'), scopeNodeId: 'missing' }), /范围/);
  const tooMany = document();
  for (let i = 0; i < 198; i++) tooMany.nodes.push({ ...tooMany.nodes[1], id: `n${i}` });
  assert.throws(() => validateCandidate({ document: tooMany, summary: '生成' }, request()), /200/);
});

test('candidate preserves scope boundary, root, stable IDs, version and metadata', () => {
  const req = request('revise');
  const good = result(req); good.document.nodes[1].text = '电路分析';
  good.document.nodes.push({ ...good.document.nodes[1], id: 'new', parentId: 'branch', text: '欧姆定律' });
  assert.equal(validateCandidate(good, req).baseRevision, 3);
  for (const mutate of [
    d => d.nodes[2].text = '偷改范围外',
    d => d.nodes[1].parentId = 'outside',
    d => d.rootId = 'branch',
    d => d.revision++,
    d => d.documentId = 'other',
    d => d.nodes[1].id = 'replacement',
    d => d.nodes.push({ ...d.nodes[1], id: 'new-outside', parentId: 'root' }),
    d => d.title = '偷改标题',
    d => d.sourceText = '替换原文'
    , d => d.thinking = 'hidden reasoning'
  ]) { const output = result(req); mutate(output.document); assert.throws(() => validateCandidate(output, req)); }
});

test('health exposes configuration only; unconfigured generation returns 503', async t => {
  const server = createGateway({ env: {} }), url = await listen(server);
  t.after(() => close(server));
  const health = await (await fetch(`${url}/api/health`)).json();
  assert.equal(health.configured, false); assert.equal(health.model, '');
  const response = await post(url, request()); assert.equal(response.status, 503);
  assert.equal((await response.json()).code, 'NOT_CONFIGURED');
});

test('message preservation compares semantic fields, preserving array order but ignoring JSON key order', () => {
  const req = request('revise');
  req.document.messages = [
    { id: 'user-message', role: 'user', content: '扩充这个分支', createdAt: '2026-11-03T00:00:00.000Z' },
    { id: 'assistant-message', role: 'assistant', content: '已整理', createdAt: '2026-11-03T00:00:01.000Z' }
  ];
  req.messages = clone(req.document.messages);
  const valid = result(req);
  valid.document.messages = req.document.messages.map(message => ({
    role: message.role, content: message.content, createdAt: message.createdAt, id: message.id
  }));
  assert.deepEqual(validateCandidate(valid, req).document.messages, req.document.messages);
  for (const mutate of [
    messages => messages.reverse(),
    messages => messages.pop(),
    messages => { messages[0].content = '模型篡改内容'; },
    messages => { messages[0].id = 'reassigned'; },
    messages => { messages[0].role = 'assistant'; },
    messages => { messages[0].createdAt = '2026-11-03T00:00:02.000Z'; }
  ]) {
    const invalid = result(req); mutate(invalid.document.messages);
    assert.throws(() => validateCandidate(invalid, req), /不可更改文档对话历史/);
  }
});

test('streamed UTF-8 produces one valid candidate, no hidden reasoning; deduplicates completed request', async t => {
  const fixture = await setup(t, async (_req, res) => emit(res, result(), true));
  const response = await post(fixture.url, request()); assert.equal(response.status, 200);
  const text = await response.text(), data = events(text);
  assert.equal(data.filter(e => e.type === 'candidate').length, 1);
  assert.equal(data.at(-1).type, 'done'); assert.ok(!text.includes('HIDDEN_REASONING'));
  assert.equal(data.find(e => e.type === 'candidate').candidate.document.documentId, 'map_test');
  const second = await post(fixture.url, request()); await second.text(); assert.equal(fixture.calls(), 1);
  const conflict = await post(fixture.url, { ...request(), instruction: '不同内容' }); assert.equal(conflict.status, 409);
});

test('repairs invalid output once, and never emits an invalid candidate', async t => {
  const fixture = await setup(t, async (_req, res, payload, count) => {
    if (count === 2) assert.equal(payload.messages.length, 4);
    return emit(res, count === 1 ? '{broken-json' : result());
  });
  const response = await post(fixture.url, request()); const data = events(await response.text());
  assert.equal(fixture.calls(), 2); assert.equal(data.filter(e => e.type === 'candidate').length, 1);
  assert.ok(data.some(e => e.type === 'progress' && e.message.includes('修复')));
});

test('two invalid results produce error+done without candidate', async t => {
  const fixture = await setup(t, async (_req, res) => emit(res, '{}'));
  const data = events(await (await post(fixture.url, request())).text());
  assert.equal(fixture.calls(), 2); assert.ok(!data.some(e => e.type === 'candidate'));
  assert.equal(data.at(-2).code, 'INVALID_MODEL_OUTPUT'); assert.equal(data.at(-1).type, 'done');
});

test('same document locks concurrent work; cancelling closes upstream and releases lock', async t => {
  let startedResolve, endedResolve;
  const started = new Promise(resolve => { startedResolve = resolve; });
  const ended = new Promise(resolve => { endedResolve = resolve; });
  const fixture = await setup(t, async (_req, res, _payload, count) => {
    if (count > 1) return emit(res, result());
    res.writeHead(200, { 'Content-Type': 'text/event-stream' }); res.write(': heartbeat\n\n');
    res.on('close', endedResolve); startedResolve();
  });
  const controller = new AbortController();
  const first = await post(fixture.url, request(), { signal: controller.signal });
  await started;
  const conflict = await post(fixture.url, request('create', 'different-request')); assert.equal(conflict.status, 409);
  const duplicate = await post(fixture.url, request()); assert.equal(duplicate.status, 409);
  controller.abort(); await assert.rejects(first.text());
  await ended;
  // Upstream socket closure precedes the gateway's finally by a microtask.
  await new Promise(resolve => setTimeout(resolve, 20));
  const retry = await post(fixture.url, request()); assert.equal(retry.status, 200); await retry.text();
  assert.equal(fixture.calls(), 2);
});

test('timeout, provider authentication failure, malformed body and oversized body are explicit', async t => {
  const slow = await setup(t, async (_req, res) => { res.writeHead(200, { 'Content-Type': 'text/event-stream' }); res.write(': pending\n\n'); }, { timeoutMs: 30 });
  const timed = events(await (await post(slow.url, request())).text()); assert.equal(timed.at(-2).code, 'GENERATION_TIMEOUT');
  const bad = await setup(t, async (_req, res) => { res.writeHead(401); res.end('private upstream detail'); });
  const output = await (await post(bad.url, request())).text(); assert.ok(output.includes('UPSTREAM_ERROR')); assert.ok(!output.includes('private upstream detail'));
  const malformed = await post(bad.url, request(), { body: 'not json' }); assert.equal(malformed.status, 400);
  const huge = await post(bad.url, request(), { body: 'x'.repeat(513 * 1024) }); assert.equal(huge.status, 413);
});
