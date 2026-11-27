import { VisualLesson, validateLesson } from './LessonScript';
// API24-compatible metadata stored inside the existing note field. Existing
// persistence, revisions, undo and JSON backups remain the only source of truth.
export interface StudyLink { title: string; url: string; }
export interface NodeStudy {
  version: number;
  lessonId: string;
  language: string;
  code: string;
  links: StudyLink[];
  generated?: VisualLesson;
}
export interface StudyNote { text: string; study: NodeStudy; }
const STUDY_MARKER: string = '\n\n```flowspace-learning-v1\n';

export function emptyStudy(): NodeStudy {
  return { version: 1, lessonId: '', language: 'C++', code: '', links: [] };
}

export function validStudyUrl(url: string): boolean {
  // Browser destinations only; no script/file/data URLs or embedded credentials.
  return /^https:\/\/[^\s\/@?#:]+(?::\d{1,5})?(?:[\/?#][^\s]*)?$/.test(url) &&
    url.length <= 2000 && !/[<>"\\\u0000-\u001f]/.test(url);
}

export function validateStudy(study: NodeStudy): void {
  if (!study || study.version !== 1) throw new Error('不支持的节点资料版本，请保留原备注。');
  if (typeof study.lessonId !== 'string' || !['', 'ring', 'queue', 'stack'].includes(study.lessonId)) {
    throw new Error('请选择已有的动态讲解；暂不支持这个讲解类型。');
  }
  if (typeof study.language !== 'string' || study.language.length > 30 ||
    typeof study.code !== 'string' || study.code.length > 6000) throw new Error('代码最多 6000 字，语言最多 30 字。');
  if (!Array.isArray(study.links) || study.links.length > 8) throw new Error('每个节点最多添加 8 个资料链接。');
  if (study.generated !== undefined) validateLesson(study.generated);
  study.links.forEach((link: StudyLink) => {
    if (!link || typeof link.title !== 'string' || !link.title.trim() || link.title.length > 120 ||
      typeof link.url !== 'string' || !validStudyUrl(link.url)) throw new Error('请填写链接标题和有效的 HTTPS 原站地址。');
  });
}

export function decodeStudyNote(note: string): StudyNote {
  const index: number = note.lastIndexOf(STUDY_MARKER);
  if (index < 0) return { text: note, study: emptyStudy() };
  const tail: string = note.slice(index + STUDY_MARKER.length);
  if (!tail.endsWith('\n```')) throw new Error('节点资料区块不完整，请先在节点备注中检查，原内容已保留。');
  let study: NodeStudy;
  try { study = JSON.parse(tail.slice(0, -4)) as NodeStudy; }
  catch (_) { throw new Error('节点资料格式损坏，原备注未被覆盖，请在节点备注中检查。'); }
  validateStudy(study);
  return { text: note.slice(0, index), study: study };
}

export function encodeStudyNote(text: string, study: NodeStudy): string {
  validateStudy(study);
  if (text.includes(STUDY_MARKER)) throw new Error('说明中含资料区块标记，请先检查节点备注。');
  const hasStudy: boolean = study.lessonId !== '' || study.code !== '' || study.links.length > 0 || study.generated !== undefined;
  const note: string = hasStudy ? text + STUDY_MARKER + JSON.stringify(study) + '\n```' : text;
  if (note.length > 10000) throw new Error('说明、链接和代码合计超过节点备注 10000 字上限，请缩短后保存。');
  return note;
}
