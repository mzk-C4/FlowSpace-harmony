import { http } from '@kit.NetworkKit';
import { VisualLesson, validateLesson } from './LessonScript';
import { StudyLink } from './NodeLearning';
export interface LessonRequest {
  requestId: string;
  documentId: string;
  nodeId: string;
  baseRevision: number;
  topic: string;
  instruction: string;
  context: string;
  code: string;
  links: StudyLink[];
}
interface LessonResponse {
  requestId: string;
  documentId: string;
  nodeId: string;
  baseRevision: number;
  script: VisualLesson;
  message?: string;
}
class LessonClient {
  private active: http.HttpRequest | null = null;
  private rejectActive: ((reason: Error) => void) | null = null;
  cancel(): void { if (this.rejectActive !== null) this.rejectActive(new Error('已取消讲解生成，节点资料已保留。')); }
  generate(baseUrl: string, input: LessonRequest): Promise<VisualLesson> {
    if (this.active !== null) return Promise.reject(new Error('已有讲解正在生成，请先等待或取消。'));
    const base: string = baseUrl.trim().replace(/\/+$/, '');
    if (!/^https?:\/\/[^\s]+$/.test(base)) return Promise.reject(new Error('请先在个人页设置后端地址。'));
    return new Promise<VisualLesson>((resolve, reject) => {
      const request: http.HttpRequest = http.createHttp();
      this.active = request;
      let settled: boolean = false;
      const finish = (): void => { this.active = null; this.rejectActive = null; request.destroy(); };
      const fail = (reason: Error): void => { if (!settled) { settled = true; finish(); reject(reason); } };
      this.rejectActive = fail;
      request.request(base + '/api/lessons/generate', {
        method: http.RequestMethod.POST, header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify(input), expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000, readTimeout: 180000, maxLimit: 131072
      }).then((response: http.HttpResponse) => {
        if (settled) return;
        try {
          const data: LessonResponse = JSON.parse(response.result as string) as LessonResponse;
          if (response.responseCode !== 200) throw new Error(data.message || '讲解生成失败：HTTP ' + response.responseCode);
          if (data.requestId !== input.requestId || data.documentId !== input.documentId ||
            data.nodeId !== input.nodeId || data.baseRevision !== input.baseRevision) throw new Error('讲解响应不属于当前节点版本，请重试。');
          validateLesson(data.script);
          if (data.script.sourceUrl && !input.links.some((link: StudyLink) => link.url === data.script.sourceUrl)) throw new Error('讲解来源与提供的链接不一致。');
          settled = true; finish(); resolve(data.script);
        } catch (error) { fail(new Error((error as Error).message || '讲解响应格式无效。')); }
      }).catch((error: Error) => { fail(new Error('无法生成讲解，请检查后端连接。' + error.message)); });
    });
  }
}
export const lessonClient: LessonClient = new LessonClient();
