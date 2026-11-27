// Preview-only host: actual shipped page/player, no provider credentials.
import { NodeLearningPage } from '../learning/NodeLearningPage';
import { encodeStudyNote, emptyStudy, StudyLink } from '../learning/NodeLearning';
import { LessonRequest } from '../learning/LessonClient';
import { VisualLesson } from '../learning/LessonScript';

@Entry
@ComponentV2
struct LibraryPreview {
  @Local screen: string = 'ring';
  @Local note: string = encodeStudyNote('环形数组通过取模实现回绕。为节点附上自己的链接和代码，然后生成适合你的分步讲解。', {
    version: 1, lessonId: '', language: 'C++', code: 'start = (start + capacity - 1) % capacity;\na[start] = value;\n++size;',
    links: [{ title: 'C++ 队列接口参考', url: 'https://en.cppreference.com/w/cpp/container/queue.html' }]
  });
  @Local revision: number = 0;
  @Local message: string = '';
  build() {
    Column() {
      Row({ space: 8 }) {
        Button('动态演示').height(44).fontSize(13).backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent'))
          .onClick(() => { this.screen = 'ring'; })
        Button('节点资料').height(44).fontSize(13).backgroundColor($r('app.color.fs_soft')).fontColor($r('app.color.fs_accent'))
          .onClick(() => { this.screen = 'node'; })
      }.width('100%').padding(8)
      if (this.screen === 'ring') {
        NodeLearningPage({ title: '栈与队列', previewLessonId: 'ring', onClose: () => { this.screen = 'node'; },
          onOpenLink: (link: StudyLink) => { this.message = '预览不启动外部浏览器：' + link.title; }, externalError: this.message })
      } else {
        NodeLearningPage({ title: '环形数组 · 节点资料', note: this.note, nodeId: 'preview-node', documentId: 'preview-document',
          revision: this.revision, saveStatus: '预览会话 · 非数据库验收', externalError: this.message,
          onClose: () => { this.screen = 'ring'; },
          onSave: (note: string, revision: number) => {
            if (revision !== this.revision) return false;
            this.note = note; this.revision++; return true;
          },
          onGenerate: (_request: LessonRequest): Promise<VisualLesson> => Promise.reject(new Error('预览宿主未连接模型；正式应用复用个人页网关配置。')),
          onOpenLink: (link: StudyLink) => { this.message = '预览不启动外部浏览器：' + link.title; } })
      }
    }.width('100%').height('100%').backgroundColor($r('app.color.fs_surface'))
  }
}
