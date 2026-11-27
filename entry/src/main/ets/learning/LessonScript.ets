export interface LessonStep {
  title: string;
  explanation: string;
  operation: string;
  cells: string[];
  active: number;
  start: number;
  end: number;
  codeLine: number;
}
export interface VisualLesson {
  id: string;
  kind: string;
  title: string;
  summary: string;
  invariant: string;
  sourceTitle: string;
  sourceUrl: string;
  code: string[];
  steps: LessonStep[];
}
export function validateLesson(lesson: VisualLesson): void {
  if (!lesson || lesson.id !== 'generated' || !['array', 'stack', 'flow', 'compare'].includes(lesson.kind)) {
    throw new Error('讲解格式无效，只支持数组、栈、流程与对照图。');
  }
  const texts: string[] = [lesson.title, lesson.summary, lesson.invariant, lesson.sourceTitle, lesson.sourceUrl];
  const limits: number[] = [120, 800, 600, 120, 2000];
  texts.forEach((value: string, index: number) => {
    if (typeof value !== 'string' || value.length > limits[index] || (index < 3 && !value.trim())) throw new Error('讲解标题或说明无效。');
  });
  if (lesson.sourceUrl !== '' && !/^https:\/\/[^\s\/@?#:]+(?::\d{1,5})?(?:[\/?#][^\s]*)?$/.test(lesson.sourceUrl)) throw new Error('讲解来源地址无效。');
  if (!Array.isArray(lesson.code) || lesson.code.length > 40 ||
    lesson.code.some((line: string) => typeof line !== 'string' || line.length > 200)) throw new Error('讲解代码过长。');
  if (!Array.isArray(lesson.steps) || lesson.steps.length < 2 || lesson.steps.length > 12) throw new Error('讲解应有 2–12 步。');
  lesson.steps.forEach((step: LessonStep) => {
    if (!step || typeof step.title !== 'string' || !step.title.trim() || step.title.length > 120 ||
      typeof step.explanation !== 'string' || !step.explanation.trim() || step.explanation.length > 600 ||
      typeof step.operation !== 'string' || step.operation.length > 160 || !Array.isArray(step.cells) || step.cells.length > 8 ||
      step.cells.some((cell: string) => typeof cell !== 'string' || cell.length > 80)) throw new Error('讲解步骤内容无效。');
    [step.active, step.start, step.end].forEach((index: number) => {
      if (!Number.isInteger(index) || index < -1 || index >= step.cells.length) throw new Error('可视元素索引越界。');
    });
    if (!Number.isInteger(step.codeLine) || step.codeLine < -1 || step.codeLine >= lesson.code.length) throw new Error('代码高亮行越界。');
  });
  if (JSON.stringify(lesson).length > 8000) throw new Error('讲解过长，请缩小主题后重新生成。');
}
