import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { fileURLToPath } from 'node:url';
import { createGateway } from '../../backend/server.mjs';

// Exercise the shipped ArkTS source, not a second implementation of its parser.
// Only the two native Kit imports and erased domain types are substituted.
const source = readFileSync(fileURLToPath(new URL('../../entry/src/main/ets/services/GenerationClient.ets', import.meta.url)), 'utf8')
  .replace(/^import .*;\r?\n/gm, '');
const javascript = stripTypeScriptTypes(source, { mode: 'transform' });
let moduleSequence = 0;
const tick = () => new Promise(resolve => setImmediate(resolve));
const arrayBuffer = bytes => bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength);
const event = data => `data: ${JSON.stringify(data)}\n\n`;

function sample() {
  const document = { schemaVersion: 1, documentId: 'client_map', title: '中文导图', revision: 0, rootId: 'client_root',
    nodes: [{ id: 'client_root', parentId: '', order: 0, text: '中文导图', note: '', collapsed: false }],
    layout: 'right', sourceText: '介绍欧姆定律', messages: [], createdAt: '2026-11-03T00:00:00.000Z', updatedAt: '2026-11-03T00:00:00.000Z' };
  const request = { requestId: 'client_request', documentId: document.documentId, baseRevision: document.revision,
    mode: 'create', instruction: '介绍欧姆定律', scopeNodeId: '', document, messages: [] };
  const candidate = { requestId: request.requestId, baseRevision: request.baseRevision, document, summary: '已生成中文导图' };
  return { request, candidate };
}

class NativeHttpDouble {
  handlers = new Map(); destroyed = false; destroyCalls = 0;
  constructor() {
    this.statusPromise = new Promise((resolve, reject) => { this.resolveStatus = resolve; this.rejectStatus = reject; });
  }
  on(type, handler) { this.handlers.set(type, handler); }
  emit(type, data) { this.handlers.get(type)?.(data); }
  requestInStream(url, options) { this.url = url; this.options = options; return this.statusPromise; }
  async request(url, options) { this.url = url; this.options = options; return this.healthResponse; }
  destroy() { this.destroyCalls++; this.destroyed = true; }
  bytes(text, split = 1) {
    const bytes = Buffer.from(text);
    for (let offset = 0; offset < bytes.length; offset += split) {
      this.emit('dataReceive', arrayBuffer(bytes.subarray(offset, offset + split)));
    }
  }
}

async function clientHarness(factory = () => new NativeHttpDouble()) {
  const nativeRequests = [];
  globalThis.http = {
    RequestMethod: { POST: 'POST', GET: 'GET' }, HttpDataType: { STRING: 0 },
    createHttp: () => { const request = factory(); nativeRequests.push(request); return request; }
  };
  globalThis.util = { TextDecoder: { create: encoding => {
    const decoder = new TextDecoder(encoding);
    return { decodeWithStream: (bytes, options) => decoder.decode(bytes, options) };
  } } };
  const module = await import('data:text/javascript;base64,' + Buffer.from(javascript + `\n// instance ${++moduleSequence}`).toString('base64'));
  return { client: module.generationClient, nativeRequests };
}
test.after(() => { delete globalThis.http; delete globalThis.util; });

for (const order of ['status-first', 'dataEnd-first']) {
  test(`actual client preserves one-byte Chinese UTF-8 and CRLF SSE; ${order}`, async () => {
    const { client, nativeRequests } = await clientHarness();
    const { request, candidate } = sample(), progress = [];
    let settled = false;
    const pending = client.generate(' http://127.0.0.1:8787/// ', request, message => progress.push(message));
    pending.then(() => { settled = true; });
    const native = nativeRequests[0];
    assert.equal(native.url, 'http://127.0.0.1:8787/api/mindmaps/generate');
    assert.equal(native.options.method, 'POST');
    assert.equal(native.options.header.Accept, 'text/event-stream');
    assert.deepEqual(JSON.parse(native.options.extraData), request);
    const body = (': keep-alive\n\n' + event({ type: 'progress', message: '正在生成中文节点…' }) +
      event({ type: 'candidate', candidate }) + event({ type: 'done' })).replace(/\n/g, '\r\n');
    if (order === 'status-first') { native.resolveStatus(200); await tick(); }
    native.bytes(body);
    await tick(); assert.equal(settled, false, 'candidate alone must wait for dataEnd and status');
    native.emit('dataEnd');
    if (order === 'dataEnd-first') {
      await tick(); assert.equal(settled, false, 'dataEnd alone must wait for HTTP status');
      native.resolveStatus(200);
    }
    assert.deepEqual(await pending, candidate);
    assert.deepEqual(progress, ['正在生成中文节点…']);
    assert.equal(native.destroyCalls, 1);
  });

  test(`actual client reports JSON 503 message instead of missing-candidate error; ${order}`, async () => {
    const { client, nativeRequests } = await clientHarness();
    const pending = client.generate('http://localhost:8787', sample().request, () => {});
    const rejected = assert.rejects(pending, /AI 服务未配置，请填写模型密钥/);
    const native = nativeRequests[0];
    if (order === 'status-first') { native.resolveStatus(503); await tick(); }
    native.bytes(JSON.stringify({ code: 'NOT_CONFIGURED', message: 'AI 服务未配置，请填写模型密钥' }), 2);
    native.emit('dataEnd');
    if (order === 'dataEnd-first') native.resolveStatus(503);
    await rejected; assert.equal(native.destroyCalls, 1);
  });
}

test('cancel destroys native request, rejects once, blocks duplicate concurrency, then permits next request', async () => {
  const { client, nativeRequests } = await clientHarness();
  const { request, candidate } = sample();
  const first = client.generate('http://localhost', request, () => {});
  const cancelled = assert.rejects(first, /已取消生成/);
  await assert.rejects(client.generate('http://localhost', request, () => {}), /已有生成请求/);
  assert.equal(nativeRequests.length, 1);
  client.cancel(); client.cancel(); await cancelled;
  assert.equal(nativeRequests[0].destroyCalls, 1);
  const second = client.generate('http://localhost', request, () => {});
  // Late callbacks from the destroyed first connection must not clear the new lock.
  nativeRequests[0].resolveStatus(200); nativeRequests[0].emit('dataEnd'); await tick();
  await assert.rejects(client.generate('http://localhost', request, () => {}), /已有生成请求/);
  nativeRequests[1].resolveStatus(200);
  nativeRequests[1].bytes(event({ type: 'candidate', candidate }) + event({ type: 'done' }));
  nativeRequests[1].emit('dataEnd');
  assert.deepEqual(await second, candidate); assert.equal(nativeRequests[1].destroyCalls, 1);
});

test('no candidate, malformed SSE, server SSE errors and native request errors reject and release resources', async () => {
  const cases = [
    { text: event({ type: 'progress', message: '处理中' }) + event({ type: 'done' }), expected: /未返回完整导图/ },
    { text: 'data: {broken-json}\n\n', expected: /无效的数据流/ },
    { text: event({ type: 'error', code: 'INVALID_MODEL_OUTPUT', message: '结构修复失败' }) + event({ type: 'done' }), expected: /结构修复失败/ },
    { error: new Error('connection reset'), expected: /无法完成生成.*connection reset/ }
  ];
  for (const scenario of cases) {
    const { client, nativeRequests } = await clientHarness();
    const pending = client.generate('http://localhost', sample().request, () => {});
    const rejected = assert.rejects(pending, scenario.expected), native = nativeRequests[0];
    if (scenario.error) native.rejectStatus(scenario.error);
    else { native.resolveStatus(200); native.bytes(scenario.text, 3); native.emit('dataEnd'); }
    await rejected; assert.equal(native.destroyCalls, 1);
    const next = client.generate('http://localhost', sample().request, () => {});
    const nextRejected = assert.rejects(next, /已取消生成/); client.cancel(); await nextRejected;
  }
});

test('response-size limit and invalid base URL fail safely', async () => {
  const { client, nativeRequests } = await clientHarness();
  for (const url of ['', 'file:///tmp', 'http://bad address']) {
    await assert.rejects(client.generate(url, sample().request, () => {}), /有效的后端地址/);
  }
  assert.equal(nativeRequests.length, 0);
  const pending = client.generate('http://localhost', sample().request, () => {});
  const rejected = assert.rejects(pending, /响应过大/);
  nativeRequests[0].emit('dataReceive', new ArrayBuffer(2097153));
  await rejected; assert.equal(nativeRequests[0].destroyCalls, 1);
});

test('health uses the actual native API and destroys requests on both success and malformed status', async () => {
  const { client, nativeRequests } = await clientHarness(() => {
    const native = new NativeHttpDouble();
    native.healthResponse = { responseCode: 200, result: JSON.stringify({ configured: true, model: 'test-model', message: '尚未验证供应商' }) };
    return native;
  });
  assert.deepEqual(await client.health('http://localhost/'), { configured: true, model: 'test-model', message: '尚未验证供应商' });
  assert.equal(nativeRequests[0].url, 'http://localhost/api/health'); assert.equal(nativeRequests[0].destroyCalls, 1);
  const bad = await clientHarness(() => {
    const native = new NativeHttpDouble(); native.healthResponse = { responseCode: 200, result: '{}' }; return native;
  });
  await assert.rejects(bad.client.health('http://localhost'), /FlowSpace 服务状态/);
  assert.equal(bad.nativeRequests[0].destroyCalls, 1);
});

// Native request/decoder substitutes connect the *actual* ArkTS client to the
// real Node gateway. Only the external LLM is replaced by a local HTTP provider.
class FetchNativeDouble extends NativeHttpDouble {
  controller = new AbortController();
  requestInStream(url, options) {
    this.url = url; this.options = options;
    (async () => {
      try {
        const response = await fetch(url, { method: options.method, headers: options.header, body: options.extraData, signal: this.controller.signal });
        this.resolveStatus(response.status);
        for await (const bytes of response.body) this.emit('dataReceive', arrayBuffer(bytes));
        this.emit('dataEnd');
      } catch (error) { this.rejectStatus(error); }
    })();
    return this.statusPromise;
  }
  async request(url) {
    const response = await fetch(url, { signal: this.controller.signal });
    return { responseCode: response.status, result: await response.text() };
  }
  destroy() { super.destroy(); this.controller.abort(); }
}

async function listen(server) {
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  return `http://127.0.0.1:${server.address().port}`;
}
async function close(server) { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }

test('actual client and actual backend interoperate through local fake LLM, including dedupe and unconfigured 503', async t => {
  let calls = 0;
  const upstream = createServer(async (req, res) => {
    calls++; let body = ''; for await (const chunk of req) body += chunk;
    const input = JSON.parse(body), user = JSON.parse(input.messages[1].content);
    const output = JSON.stringify({ document: user.document, summary: '真实网关协议已验证' });
    res.writeHead(200, { 'Content-Type': 'text/event-stream' });
    for (const text of [output.slice(0, 37), output.slice(37)]) {
      res.write(event({ choices: [{ delta: { content: text, reasoning_content: 'must-not-leak' } }] })); await tick();
    }
    res.end('data: [DONE]\n\n');
  });
  const upstreamUrl = await listen(upstream);
  const gateway = createGateway({ env: { LLM_BASE_URL: `${upstreamUrl}/v1`, LLM_MODEL: 'local-fake', LLM_API_KEY: 'fake-key' } });
  const gatewayUrl = await listen(gateway);
  const unconfigured = createGateway({ env: {} }), unconfiguredUrl = await listen(unconfigured);
  t.after(async () => { await close(gateway); await close(unconfigured); await close(upstream); });
  const { client } = await clientHarness(() => new FetchNativeDouble());
  const { request } = sample(), progress = [];
  assert.equal((await client.health(gatewayUrl)).configured, true);
  const candidate = await client.generate(gatewayUrl, request, message => progress.push(message));
  assert.equal(candidate.requestId, request.requestId); assert.equal(candidate.baseRevision, request.baseRevision);
  assert.equal(candidate.document.nodes[0].text, '中文导图');
  assert.equal(candidate.summary, '真实网关协议已验证'); assert.ok(!JSON.stringify(candidate).includes('must-not-leak'));
  assert.ok(progress.length > 0);
  await client.generate(gatewayUrl, request, () => {}); assert.equal(calls, 1);
  await assert.rejects(client.generate(unconfiguredUrl, request, () => {}), /AI 服务未配置/);
});
