import { randomUUID } from 'node:crypto';
import { readFile, mkdir, open, writeFile, link, unlink } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { validateRequest, validateCandidate, validateDocument } from '../backend/validation.mjs';

const HELP = `用法（Node.js 24）：
  node tools/try-generation.mjs '自然语言主题'
  node tools/try-generation.mjs --file <UTF8长文> [--port 8787]
  node tools/try-generation.mjs --help

仅请求 http://127.0.0.1:<端口>/api/mindmaps/generate，不读取密钥。
请先启动并配置现有 backend 网关。输入最多 20000 字符。
完成且校验通过后，将新 JSON 备份写入 artifacts/，可导入浏览器预览和鸿蒙应用。
Ctrl+C 取消；断网、未配置、错误或数据流不完整均不保存导图。`;
const ARTIFACTS = fileURLToPath(new URL('../artifacts/', import.meta.url));

function portNumber(value) {
  if (!/^\d+$/.test(String(value)) || !Number.isInteger(Number(value)) || Number(value) < 1 || Number(value) > 65535) {
    throw Error('--port 必须是 1–65535 的本机端口');
  }
  return Number(value);
}

export function parseArgs(args) {
  let port = 8787, file, text;
  const seen = new Set();
  if (args.length === 1 && ['--help', '-h'].includes(args[0])) return { help: true };
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--port' || arg === '--file') {
      if (seen.has(arg) || !args[i + 1] || args[i + 1].startsWith('--')) throw Error(arg + ' 缺少参数或重复出现');
      seen.add(arg);
      if (arg === '--port') port = portNumber(args[++i]); else file = args[++i];
    } else if (arg.startsWith('-')) throw Error('未知选项：' + arg + '；使用 --help 查看用法');
    else if (text !== undefined) throw Error('主题请用引号包起来；只能提供一个主题或 --file');
    else text = arg;
  }
  if ((file !== undefined) === (text !== undefined)) throw Error('请提供一个主题或 --file，二者不能同时使用；使用 --help 查看用法');
  return { port, file, text };
}

export function createGenerationRequest(instruction) {
  if (typeof instruction !== 'string' || !instruction.trim() || instruction.length > 20000) {
    throw Error('输入需要 1–20000 字符的非空主题或长文');
  }
  const now = new Date().toISOString(), documentId = 'map_' + randomUUID(), rootId = 'node_' + randomUUID();
  const title = instruction.trim().split(/\r?\n/)[0].slice(0, 200);
  const document = { schemaVersion: 1, documentId, title, revision: 0, rootId,
    nodes: [{ id: rootId, parentId: '', order: 0, text: title, note: '', collapsed: false }],
    layout: 'right', sourceText: instruction, messages: [], createdAt: now, updatedAt: now };
  return validateRequest({ requestId: 'request_' + randomUUID(), documentId, baseRevision: 0,
    mode: 'create', instruction, scopeNodeId: rootId, document, messages: [] });
}

function onlyKeys(value, keys) {
  return value && typeof value === 'object' && !Array.isArray(value) && Object.keys(value).every(key => keys.includes(key));
}

// Gateway frames are distinct from the provider's OpenAI-format SSE. Keep the
// native client's candidate+done rule, and validate every complete gateway frame.
export async function readGatewayStream(body, request, onProgress = () => {}) {
  const decoder = new TextDecoder('utf-8', { fatal: true });
  let buffer = '', bytes = 0, candidate, done = false;
  function frame(text) {
    const lines = text.split('\n').filter(line => line && !line.startsWith(':'));
    if (!lines.length) return;
    if (lines.length !== 1 || !lines[0].startsWith('data:')) throw Error('网关 SSE 消息格式无效');
    let event;
    try { event = JSON.parse(lines[0].slice(5).trimStart()); } catch { throw Error('网关 SSE JSON 无效'); }
    if (done || !event || typeof event.type !== 'string') throw Error('网关结束后收到额外消息，或消息类型无效');
    if (event.type === 'progress') {
      if (!onlyKeys(event, ['type', 'message']) || typeof event.message !== 'string' || event.message.length > 1000) throw Error('网关进度消息无效');
      onProgress(event.message);
    } else if (event.type === 'candidate') {
      const value = event.candidate;
      if (candidate || !onlyKeys(event, ['type', 'candidate']) || !onlyKeys(value, ['requestId', 'baseRevision', 'document', 'summary']) ||
        value.requestId !== request.requestId || value.baseRevision !== request.baseRevision) throw Error('候选重复，或候选请求身份/版本不匹配');
      candidate = validateCandidate({ document: value.document, summary: value.summary }, request);
    } else if (event.type === 'error') {
      if (!onlyKeys(event, ['type', 'code', 'message']) || typeof event.code !== 'string' || typeof event.message !== 'string') throw Error('网关错误消息无效');
      throw Error(`网关生成失败（${event.code}）：${event.message}`);
    } else if (event.type === 'done') {
      if (!onlyKeys(event, ['type']) || !candidate) throw Error('网关结束时没有完整候选');
      done = true;
    } else throw Error('未知网关 SSE 消息类型');
  }
  for await (const chunk of body) {
    bytes += chunk.byteLength;
    if (bytes > 8 * 1024 * 1024) throw Error('网关数据流超过 8MB');
    buffer += decoder.decode(chunk, { stream: true });
    buffer = buffer.replace(/\r\n/g, '\n');
    let boundary;
    while ((boundary = buffer.indexOf('\n\n')) >= 0) {
      const complete = buffer.slice(0, boundary); buffer = buffer.slice(boundary + 2); frame(complete);
    }
  }
  buffer += decoder.decode();
  if (buffer.trim() || !done || !candidate) throw Error('网关数据流被截断，缺少完整 candidate / done');
  return candidate;
}

export async function runGeneration({ instruction, port = 8787, artifactDir = ARTIFACTS,
  signal, timeoutMs = 130000, onProgress = () => {} }) {
  const request = createGenerationRequest(instruction);
  const endpoint = `http://127.0.0.1:${portNumber(port)}/api/mindmaps/generate`;
  const combined = signal ? AbortSignal.any([signal, AbortSignal.timeout(timeoutMs)]) : AbortSignal.timeout(timeoutMs);
  let response;
  try {
    response = await fetch(endpoint, { method: 'POST', redirect: 'error', signal: combined,
      headers: { 'Content-Type': 'application/json', Accept: 'text/event-stream' }, body: JSON.stringify(request) });
    if (!response.ok) {
      let message = `网关返回 HTTP ${response.status}`;
      try {
        const text = await response.text();
        if (text.length < 16000) {
          const error = JSON.parse(text);
          if (typeof error.message === 'string') message += '：' + error.message;
        }
      } catch { /* Do not expose a non-JSON upstream body. */ }
      throw Error(message);
    }
    if (!/^text\/event-stream(?:;|$)/i.test(response.headers.get('content-type') || '') || !response.body) throw Error('网关未返回 SSE 数据流');
    const candidate = await readGatewayStream(response.body, request, onProgress);
    combined.throwIfAborted();
    const document = structuredClone(candidate.document);
    document.revision = request.baseRevision + 1;
    document.updatedAt = new Date().toISOString();
    validateDocument(document);
    const text = JSON.stringify({ format: 'flowspace-mindmap', version: 1, document }, null, 2) + '\n';
    if (Buffer.byteLength(text) > 8 * 1024 * 1024) throw Error('导图备份超过 8MB，未保存');
    await mkdir(artifactDir, { recursive: true });
    const name = 'flowspace-generated-' + document.updatedAt.replace(/[:.]/g, '-') + '-' + randomUUID() + '.json';
    const output = join(resolve(artifactDir), name), temporary = output + '.tmp';
    let published = false, temporaryOwned = false, handle;
    try {
      handle = await open(temporary, 'wx');
      temporaryOwned = true;
      await writeFile(handle, text, { signal: combined });
      await handle.close(); handle = undefined;
      combined.throwIfAborted();
      await link(temporary, output); // Exclusive publication: never overwrite an existing file.
      published = true;
      combined.throwIfAborted();
    } catch (error) {
      if (published) await unlink(output).catch(() => {});
      throw error;
    } finally {
      if (handle) await handle.close().catch(() => {});
      if (temporaryOwned) await unlink(temporary).catch(() => {});
    }
    return { output, document, summary: candidate.summary };
  } catch (error) {
    if (signal?.aborted) throw Error('已取消，未保存导图文件');
    if (combined.aborted) throw Error('请求超时，未保存导图文件');
    if (error instanceof TypeError && error.message === 'fetch failed') throw Error(`无法连接本机网关 ${endpoint}；请先启动 backend 服务`);
    if (error instanceof TypeError && error.message === 'terminated') throw Error('网关数据流连接中断，未保存导图文件');
    throw error;
  } finally { if (response?.body && !response.body.locked) await response.body.cancel().catch(() => {}); }
}

export async function readInstruction(options) {
  let instruction = options.text;
  if (options.file) {
    const data = await readFile(options.file);
    if (data.byteLength > 80003) throw Error('输入文件超过 20000 字符的 UTF-8 长文大小范围');
    try { instruction = new TextDecoder('utf-8', { fatal: true }).decode(data).replace(/^\uFEFF/, ''); }
    catch { throw Error('文件不是有效 UTF-8，请先转换编码'); }
  }
  createGenerationRequest(instruction); // Validate before contacting the local gateway.
  return instruction;
}

export async function main(args = process.argv.slice(2)) {
  const options = parseArgs(args);
  if (options.help) { console.log(HELP); return; }
  const instruction = await readInstruction(options);
  const controller = new AbortController(), cancel = () => controller.abort();
  process.on('SIGINT', cancel); process.on('SIGTERM', cancel);
  try {
    const result = await runGeneration({ instruction, port: options.port, signal: controller.signal,
      onProgress: message => console.log(message.replace(/[\u0000-\u001f\u007f]/g, ' ').slice(0, 300)) });
    console.log('生成成功，可导入浏览器预览或鸿蒙应用：\n' + result.output);
  } finally { process.off('SIGINT', cancel); process.off('SIGTERM', cancel); }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch(error => { console.error('生成失败：' + error.message); process.exitCode = 1; });
}
