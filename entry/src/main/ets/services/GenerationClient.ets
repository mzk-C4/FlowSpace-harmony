import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { GenerationRequest, GenerationCandidate, HealthStatus } from '../domain/MindMap';

interface StreamEvent {
  type: string;
  message?: string;
  code?: string;
  candidate?: GenerationCandidate;
}
interface ErrorBody { message?: string; error?: string; }

class GenerationClient {
  private active: http.HttpRequest | null = null;
  private rejectActive: ((error: Error) => void) | null = null;

  private endpoint(baseUrl: string, path: string): string {
    const base: string = baseUrl.trim().replace(/\/+$/, '');
    if (!/^https?:\/\/[^\s]+$/.test(base)) throw new Error('请在个人页设置有效的后端地址');
    return base + path;
  }

  cancel(): void {
    const reject: ((error: Error) => void) | null = this.rejectActive;
    if (reject !== null) reject(new Error('已取消生成，输入和已有导图已保留'));
  }

  async health(baseUrl: string): Promise<HealthStatus> {
    const url: string = this.endpoint(baseUrl, '/api/health');
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, { method: http.RequestMethod.GET,
        connectTimeout: 10000, readTimeout: 10000, expectDataType: http.HttpDataType.STRING });
      if (response.responseCode !== 200) throw new Error('连接失败：HTTP ' + response.responseCode.toString());
      const status: HealthStatus = JSON.parse(response.result as string) as HealthStatus;
      if (typeof status.configured !== 'boolean') throw new Error('地址没有返回 FlowSpace 服务状态');
      return status;
    } finally { request.destroy(); }
  }

  generate(baseUrl: string, input: GenerationRequest, onProgress: (message: string) => void): Promise<GenerationCandidate> {
    if (this.active !== null) return Promise.reject(new Error('已有生成请求，请先取消或等待完成'));
    let url: string = '';
    try { url = this.endpoint(baseUrl, '/api/mindmaps/generate'); }
    catch (error) { return Promise.reject(error); }
    return new Promise<GenerationCandidate>((resolve, reject) => {
      const request: http.HttpRequest = http.createHttp();
      const decoder: util.TextDecoder = util.TextDecoder.create('utf-8');
      let buffer: string = '';
      let raw: string = '';
      let received: number = 0;
      let finished: boolean = false;
      let ended: boolean = false;
      let status: number = 0;
      let candidate: GenerationCandidate | null = null;
      this.active = request;
      const cleanup = (): void => {
        this.active = null;
        this.rejectActive = null;
        request.destroy();
      };
      const fail = (error: Error): void => {
        if (finished) return;
        finished = true;
        cleanup();
        reject(error);
      };
      const finish = (): void => {
        if (finished || !ended || status === 0) return;
        if (status !== 200) {
          let message: string = '生成失败：HTTP ' + status.toString();
          try {
            const body: ErrorBody = JSON.parse(raw) as ErrorBody;
            if (typeof body.message === 'string') message = body.message;
          } catch (_) {}
          fail(new Error(message));
          return;
        }
        if (candidate === null) { fail(new Error('生成未返回完整导图，请重试')); return; }
        finished = true;
        cleanup();
        resolve(candidate);
      };
      const consume = (chunk: string): void => {
        buffer += chunk;
        let newline: number = buffer.indexOf('\n');
        while (newline >= 0 && !finished) {
          const line: string = buffer.slice(0, newline).trim();
          buffer = buffer.slice(newline + 1);
          if (line.startsWith('data:')) {
            try {
              const event: StreamEvent = JSON.parse(line.slice(5).trim()) as StreamEvent;
              if (event.type === 'progress') onProgress(event.message ?? '正在整理结构…');
              else if (event.type === 'candidate' && event.candidate !== undefined) candidate = event.candidate;
              else if (event.type === 'error') { fail(new Error(event.message ?? '模型生成失败，请重试')); }
            } catch (_) { fail(new Error('服务返回了无效的数据流，原图已保留')); }
          }
          newline = buffer.indexOf('\n');
        }
      };
      this.rejectActive = fail;
      request.on('dataReceive', (bytes: ArrayBuffer) => {
        if (finished) return;
        received += bytes.byteLength;
        if (received > 2097152) { fail(new Error('服务响应过大，请缩小生成范围')); return; }
        const chunk: string = decoder.decodeWithStream(new Uint8Array(bytes), { stream: true });
        raw += chunk;
        consume(chunk);
      });
      request.on('dataEnd', () => {
        if (finished) return;
        consume(decoder.decodeWithStream(new Uint8Array(0), { stream: false }) + '\n');
        ended = true;
        finish();
      });
      request.requestInStream(url, { method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json', 'Accept': 'text/event-stream' },
        extraData: JSON.stringify(input), connectTimeout: 15000, readTimeout: 180000 })
        .then((code: number) => { status = code; finish(); })
        .catch((error: Error) => { fail(new Error('无法完成生成，请检查后端连接。' + error.message)); });
    });
  }
}
export const generationClient: GenerationClient = new GenerationClient();
