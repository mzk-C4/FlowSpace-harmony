// Integration uses the real local gateway and an explicitly controlled provider
// substitute. These tests do not establish a successful real-model connection.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { once } from 'node:events';
import { mkdtemp, readdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createGateway } from '../../backend/server.mjs';
import { parseArgs, createGenerationRequest, readGatewayStream, runGeneration, readInstruction } from '../try-generation.mjs';
import { validateDocument } from '../../backend/validation.mjs';

async function listen(server) { server.listen(0, '127.0.0.1'); await once(server, 'listening'); return server.address().port; }
async function close(server) { server.closeAllConnections(); await new Promise(resolve => server.close(resolve)); }
async function directory(t) {
  const dir = await mkdtemp(join(tmpdir(), 'flowspace-cli-test-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  return dir;
}
async function fixture(t, mode = 'success') {
  let called = 0;
  const provider = createServer(async (req, res) => {
    const chunks = []; for await (const chunk of req) chunks.push(chunk);
    const payload = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    const request = JSON.parse(payload.messages[1].content);
    called++;
    if (mode === 'error') { res.writeHead(401); res.end('controlled authentication failure'); return; }
    if (mode === 'wait') { res.writeHead(200, { 'Content-Type': 'text/event-stream' }); res.write(': controlled pending provider\n\n'); return; }
    const document = structuredClone(request.document);
    document.title = '受控上游生成：信号与系统';
    document.nodes.push({ id: 'signals_child', parentId: document.rootId, order: 0,
      text: '频域分析', note: '测试替身内容，不是真实模型生成', collapsed: false });
    if (mode === 'truncated') {
      res.writeHead(200, { 'Content-Type': 'text/event-stream' });
      res.end('data: ' + JSON.stringify({ choices: [{ delta: { content: '{"document":' } }] }) + '\n\n');
      return;
    }
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ choices: [{ message: { content: JSON.stringify({ document, summary: '受控替身生成成功' }) } }] }));
  });
  const upstreamPort = await listen(provider);
  const gateway = createGateway({ env: { LLM_BASE_URL: `http://127.0.0.1:${upstreamPort}/v1`,
    LLM_MODEL: 'controlled-test-model', LLM_API_KEY: 'test-only-placeholder' } });
  const port = await listen(gateway);
  t.after(async () => { await close(gateway); await close(provider); });
  return { port, calls: () => called };
}

test('real local gateway + controlled provider writes one importable standard backup and preserves existing files', async t => {
  const dir = await directory(t), local = await fixture(t);
  await writeFile(join(dir, 'existing.json'), 'keep me');
  const progress = [];
  const result = await runGeneration({ instruction: '梳理信号与系统的频域分析', port: local.port,
    artifactDir: dir, onProgress: message => progress.push(message) });
  assert.equal(local.calls(), 1);
  assert.ok(progress.length);
  const backup = JSON.parse(await readFile(result.output, 'utf8'));
  assert.equal(backup.format, 'flowspace-mindmap'); assert.equal(backup.version, 1);
  assert.equal(validateDocument(backup.document).revision, 1);
  assert.equal(backup.document.nodes.length, 2);
  assert.equal(backup.document.sourceText, '梳理信号与系统的频域分析');
  assert.match(backup.document.nodes[1].note, /测试替身/);
  assert.equal(await readFile(join(dir, 'existing.json'), 'utf8'), 'keep me');
  assert.equal((await readdir(dir)).length, 2);
  assert.ok(!(await readdir(dir)).some(name => name.endsWith('.tmp')));
});

test('real unconfigured local gateway fails clearly and writes no graph', async t => {
  const dir = await directory(t), gateway = createGateway({ env: {} }), port = await listen(gateway);
  t.after(() => close(gateway));
  await assert.rejects(runGeneration({ instruction: '一个主题', port, artifactDir: dir }), /503.*未配置/);
  assert.deepEqual(await readdir(dir), []);
});

test('truncated controlled provider through real gateway never saves a substitute graph', async t => {
  const dir = await directory(t), local = await fixture(t, 'truncated');
  await assert.rejects(runGeneration({ instruction: '测试截断', port: local.port, artifactDir: dir }), /INVALID_MODEL_OUTPUT/);
  assert.equal(local.calls(), 2, 'The real gateway attempts its single repair');
  assert.deepEqual(await readdir(dir), []);
});

test('controlled provider error through real gateway is explicit and creates no output', async t => {
  const dir = await directory(t), local = await fixture(t, 'error');
  await assert.rejects(runGeneration({ instruction: '测试错误', port: local.port, artifactDir: dir }), /UPSTREAM_ERROR.*鉴权失败/);
  assert.deepEqual(await readdir(dir), []);
});

test('cancelling a real local gateway request creates no output', async t => {
  const dir = await directory(t), local = await fixture(t, 'wait'), controller = new AbortController();
  await assert.rejects(runGeneration({ instruction: '测试取消', port: local.port, artifactDir: dir,
    signal: controller.signal, onProgress: () => controller.abort() }), /已取消/);
  assert.deepEqual(await readdir(dir), []);
});

test('connection failure never creates a graph', async t => {
  const dir = await directory(t), probe = createServer(), port = await listen(probe);
  await close(probe);
  await assert.rejects(runGeneration({ instruction: '测试断网', port, artifactDir: dir }), /无法连接本机网关/);
  assert.deepEqual(await readdir(dir), []);
});

function candidate(request) {
  return { requestId: request.requestId, baseRevision: request.baseRevision,
    document: structuredClone(request.document), summary: '受控协议候选' };
}
const sse = event => 'data: ' + JSON.stringify(event) + '\r\n\r\n';
async function* bytes(text) { const data = Buffer.from(text); for (let i = 0; i < data.length; i += 3) yield data.subarray(i, i + 3); }

test('gateway SSE parser preserves split UTF-8/CRLF and requires matching candidate plus done', async () => {
  const request = createGenerationRequest('中文主题');
  const result = await readGatewayStream(bytes(sse({ type: 'progress', message: '正在生成' }) +
    sse({ type: 'candidate', candidate: candidate(request) }) + sse({ type: 'done' })), request);
  assert.equal(result.document.sourceText, '中文主题');
  for (const mutate of [value => value.requestId = 'other', value => value.baseRevision++,
    value => value.document.documentId = 'other', value => value.document.revision++]) {
    const value = candidate(request); mutate(value);
    await assert.rejects(readGatewayStream(bytes(sse({ type: 'candidate', candidate: value }) + sse({ type: 'done' })), request));
  }
});

test('gateway SSE parser rejects missing done, partial packets and events after done', async () => {
  const request = createGenerationRequest('协议校验'), start = sse({ type: 'candidate', candidate: candidate(request) });
  for (const stream of [start, start + 'data: {"type":"done"}', start + sse({ type: 'done' }) + sse({ type: 'progress', message: 'late' }),
    sse({ type: 'done' }), start + start + sse({ type: 'done' }), 'data: not-json\n\n']) {
    await assert.rejects(readGatewayStream(bytes(stream), request));
  }
});

test('CLI arguments accept only a local port and one quoted topic or UTF-8 file', () => {
  assert.deepEqual(parseArgs(['信号与系统']), { port: 8787, file: undefined, text: '信号与系统' });
  assert.deepEqual(parseArgs(['--file', '长文.txt', '--port', '12345']), { port: 12345, file: '长文.txt', text: undefined });
  assert.deepEqual(parseArgs(['--help']), { help: true });
  for (const args of [[], ['--port', '0', '主题'], ['--port', '65536', '主题'], ['--port', '127.0.0.1:8787', '主题'],
    ['--port', 'https://example.com', '主题'], ['--file', 'text.txt', '主题'], ['a', 'b'], ['--key', 'private']]) assert.throws(() => parseArgs(args));
  assert.throws(() => createGenerationRequest(' '));
  assert.throws(() => createGenerationRequest('字'.repeat(20001)));
  assert.equal(createGenerationRequest('字'.repeat(20000)).instruction.length, 20000);
});

test('the actual CLI file reader accepts UTF-8/BOM and rejects invalid or oversized input before networking', async t => {
  const dir = await directory(t), file = join(dir, '长文.txt');
  await writeFile(file, '\uFEFF信号与系统\n连续与离散');
  assert.equal(await readInstruction(parseArgs(['--file', file])), '信号与系统\n连续与离散');
  await writeFile(file, Buffer.from([0xff, 0xfe, 0x81]));
  await assert.rejects(readInstruction(parseArgs(['--file', file])), /UTF-8/);
  await writeFile(file, '字'.repeat(20001));
  await assert.rejects(readInstruction(parseArgs(['--file', file])), /20000/);
});
