// Development-only client for the SDK Previewer's own native render-frame API.
// Protocol reference: openharmony/ide_previewer mock/VirtualScreen.h (40 byte
// header) and util/WebSocketServer.cpp (ws subprotocol). No browser is used.
// Optional steps JSON is [{name:'selected',tap:[x,y]}, {name:'scrolled',swipe:[x1,y1,x2,y2]}].
// Coordinates are native physical pixels; standard viewport is 1080x2340 @480dpi.
import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync, readFileSync, createWriteStream, existsSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer } from 'node:net';

const stage = process.argv[2];
const page = process.argv[3] || 'pages/Index';
const mode = process.argv[4] || 'light';
const width = Number(process.env.FLOWSPACE_PREVIEW_WIDTH || 1080);
const height = Number(process.env.FLOWSPACE_PREVIEW_HEIGHT || 2340);
if (!Number.isInteger(width) || !Number.isInteger(height) || width < 320 || height < 320 || width > 3840 || height > 3840) throw new Error('Preview dimensions must be integers from 320 to 3840 pixels');
const steps = process.argv[5] ? JSON.parse(readFileSync(process.argv[5], 'utf8').replace(/^\uFEFF/, '')) : [];
if (!stage) throw new Error('Usage: node tools/preview-native.mjs <English staging project> [pages/Index] [light|dark] [steps.json]');
const toolchain = process.env.FLOWSPACE_TOOLCHAIN || 'E:/harmony system/command-line-tools';
const bin = join(toolchain, 'sdk/default/openharmony/previewer/common/bin');
const product = join(resolve(stage), 'entry/.preview/default/intermediates');
if (!existsSync(join(product, 'loader_out/default/ets/modules.abc'))) throw new Error('Run SDK PreviewBuild in the staging project first');
const output = resolve(dirname(fileURLToPath(import.meta.url)), '../artifacts/native-preview');
mkdirSync(output, { recursive: true });
const name = page.replace(/[^A-Za-z0-9_-]/g, '-') + '-' + mode + (width === 1080 && height === 2340 ? '' : `-${width}x${height}`);
const portServer = createServer();
await new Promise(resolve => portServer.listen(0, '127.0.0.1', resolve));
const port = portServer.address().port;
await new Promise(resolve => portServer.close(resolve));
const sid = 'flowspace_native_' + Date.now();
const args = ['-j', join(product, 'loader_out/default/ets'), '-s', sid,
  '-device', 'phone', '-shape', 'rect', '-sd', '480', '-or', String(width), String(height), '-cr', String(width), String(height),
  '-n', 'entry', '-av', 'ACE_2_0', '-url', page, '-pages', 'main_pages', '-arp', join(product, 'res/default'),
  '-pm', 'Stage', '-l', 'zh_CN', '-cm', mode, '-o', 'portrait', '-ljPath', join(product, 'loader/default/loader.json'),
  '-lws', String(port), '-componentTest', '{}'];
const log = createWriteStream(join(output, name + '.log'));
let commandSocket;
const commands = createServer(connection => {
  commandSocket = connection;
  connection.on('data', data => log.write('\nCOMMAND_RESPONSE ' + data.toString('utf8') + '\n'));
});
await new Promise(resolve => commands.listen('\\\\.\\pipe\\' + sid + '_commandPipe', resolve));
writeFileSync(join(output, name + '-invocation.json'), JSON.stringify({ executable: join(bin, 'Previewer.exe'), args,
  note: 'Native SDK ArkUI preview only. Does not validate device APIs, persistent database or real AI calls.' }, null, 2));
const child = spawn(join(bin, 'Previewer.exe'), args, { cwd: bin, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
child.stdout.pipe(log); child.stderr.pipe(log);
let socket, received = 0, lastFrame;
const deadline = Date.now() + 25000;
try {
  while (Date.now() < deadline && !socket) {
    socket = await new Promise(resolve => {
      const ws = new WebSocket(`ws://127.0.0.1:${port}`, 'ws'); ws.binaryType = 'arraybuffer';
      ws.addEventListener('error', () => { try { ws.close(); } catch {} resolve(null); }, { once: true });
      ws.addEventListener('open', () => resolve(ws), { once: true });
    });
    if (!socket) await new Promise(resolve => setTimeout(resolve, 250));
  }
  if (!socket) throw new Error('Native Previewer WebSocket did not open; inspect log');
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => received ? resolve() : reject(new Error('No native render frame received')), 8000);
    socket.addEventListener('message', event => {
      const frame = Buffer.from(event.data);
      log.write('\nFRAME ' + frame.length + ' ' + frame.subarray(0, 48).toString('hex') + '\n');
      if (frame.length < 42 || frame.readUInt32BE(0) !== 0x12345678) return;
      // Page preview uses JPEG payload, exactly as sent by the SDK (no rescale).
      if (frame[40] !== 0xff || frame[41] !== 0xd8) return;
      received++; lastFrame = frame;
      if (received >= 5) { clearTimeout(timer); resolve(); }
    });
  });
  const imagePath = join(output, name + '.jpg');
  writeFileSync(imagePath, lastFrame.subarray(40));
  console.log(JSON.stringify({ imagePath, received, width: lastFrame.readUInt32BE(4), height: lastFrame.readUInt32BE(8) }));
  const sendCommand = (command, args) => {
    if (!commandSocket) throw new Error('Previewer native command pipe is unavailable');
    const message = { version: '1.0.1', type: 'action', command, args };
    log.write('\nCOMMAND_SENT ' + JSON.stringify(message) + '\n');
    commandSocket.write(JSON.stringify(message) + '\0');
  };
  for (const step of steps) {
    if (step.swipe) {
      const [startX, startY, endX, endY] = step.swipe;
      sendCommand('MousePress', { x: startX, y: startY });
      for (let index = 1; index <= 12; index++) {
        await new Promise(resolve => setTimeout(resolve, 50));
        sendCommand('MouseMove', { x: Math.round(startX + (endX - startX) * index / 12), y: Math.round(startY + (endY - startY) * index / 12) });
      }
      sendCommand('MouseRelease', { x: endX, y: endY });
    }
    if (step.tap) {
      const [x, y] = step.tap;
      sendCommand('MousePress', { x, y });
      await new Promise(resolve => setTimeout(resolve, 80));
      sendCommand('MouseRelease', { x, y });
    }
    await new Promise(resolve => setTimeout(resolve, step.waitMs || 1200));
    const stepPath = join(output, name + '-' + step.name.replace(/[^A-Za-z0-9_-]/g, '') + '.jpg');
    writeFileSync(stepPath, lastFrame.subarray(40));
    console.log(JSON.stringify({ imagePath: stepPath, received, step }));
  }
} finally {
  socket?.close(); child.kill(); commandSocket?.destroy(); commands.close(); log.end();
}
