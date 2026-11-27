// Original, deterministic teaching scripts. Never execute user-supplied code.
import { VisualLesson, LessonStep } from './LessonScript';
export { VisualLesson, LessonStep } from './LessonScript';

const RING: VisualLesson = {
  id: 'ring', kind: 'array', title: '环形数组',
  summary: '数组长度固定为 6，start 指向队头，end 指向下一个可写位置。用 size 区分空和满，跨越边界时取模回绕。',
  invariant: '0 ≤ size ≤ 6；end = (start + size) % 6。固定容量、尚未满时，两端操作为 O(1)。',
  sourceTitle: 'cppreference · std::deque（标准双端队列接口参考）',
  sourceUrl: 'https://en.cppreference.com/w/cpp/container/deque.html',
  code: ['static constexpr int N = 6;', 'int a[N] = {4, 2, 3}, start = 0, size = 3;',
    'bool addFirst(int value) {', '  if (size == N) return false;', '  start = (start + N - 1) % N;',
    '  a[start] = value;', '  ++size;', '  return true;', '}',
    'int endIndex() { return (start + size) % N; }'],
  steps: [
    { title: '初始：三个元素', explanation: '逻辑顺序为 4、2、3；start = 0，size = 3，因此 end = 3。空槽用 · 表示。', operation: 'end = (0 + 3) % 6 = 3', cells: ['4','2','3','·','·','·'], active: -1, start: 0, end: 3, codeLine: 1 },
    { title: '先检查容量', explanation: 'size 为 3，小于容量 6，可以向队头插入。若已满则返回 false，指针和元素保持不变。', operation: 'size == N ? 3 == 6 → false', cells: ['4','2','3','·','·','·'], active: -1, start: 0, end: 3, codeLine: 3 },
    { title: 'start 向前移动并回绕', explanation: '在索引 0 的前一个位置是索引 5。先加容量再取模，避免 C++ 中负数余数导致负索引。', operation: 'start: 0 → (0 + 6 - 1) % 6 = 5', cells: ['4','2','3','·','·','·'], active: 5, start: 5, end: 3, codeLine: 4 },
    { title: '在索引 5 写入 5', explanation: '把 5 写在新的队头位置。此时正在操作中，还未更新 size；物理位置回到末端，逻辑上却在 4 的前面。', operation: 'a[5] = 5', cells: ['4','2','3','·','·','5'], active: 5, start: 5, end: 3, codeLine: 5 },
    { title: '提交插入：更新长度', explanation: 'size 增加到 4，逻辑顺序为 5 → 4 → 2 → 3。操作完成后，end = (5 + 4) % 6 = 3。', operation: '++size → 4；逻辑顺序 5 → 4 → 2 → 3', cells: ['4','2','3','·','·','5'], active: 5, start: 5, end: 3, codeLine: 6 },
    { title: '读懂指针与复杂度', explanation: 'start 是已有队头，end 是下一个空位，并不指向最后一个元素。插入只更新常数个位置，不搬动已有元素。这里的实现是教学用固定数组，不是 std::deque 的内部实现。', operation: 'addFirst(5) 完成；start = 5，end = 3', cells: ['4','2','3','·','·','5'], active: -1, start: 5, end: 3, codeLine: 9 }
  ]
};
const QUEUE: VisualLesson = {
  id: 'queue', kind: 'array', title: '队列 · 先进先出', summary: '从队尾入队，从队头出队。先进入的元素先离开，适合广度优先搜索与任务排队。',
  invariant: 'front 是最早尚未移除的元素。空队列不可读取或出队；底层容器与接口复杂度需分别确认。',
  sourceTitle: 'cppreference · std::queue', sourceUrl: 'https://en.cppreference.com/w/cpp/container/queue.html',
  code: ['std::queue<int> q;', 'q.push(1);', 'q.push(2);', 'q.push(3);',
    'if (!q.empty()) {', '  int value = q.front(); // 1', '  q.pop();', '}'],
  steps: [
    { title: '建立空队列', explanation: '队列最初没有元素。只有非空时，front 和 pop 才合法。', operation: 'queue = []', cells: [], active: -1, start: -1, end: -1, codeLine: 0 },
    { title: '1 从队尾入队', explanation: '第一个元素同时是队头和队尾。', operation: 'push(1)', cells: ['1'], active: 0, start: 0, end: 0, codeLine: 1 },
    { title: '2 排在 1 后面', explanation: '不能从中间插入或直接移除队尾。队列接口约束了访问顺序。', operation: 'push(2)', cells: ['1','2'], active: 1, start: 0, end: 1, codeLine: 2 },
    { title: '3 继续排队', explanation: '队头仍然为 1，队尾变成 3。进入顺序为 1、2、3。', operation: 'push(3)', cells: ['1','2','3'], active: 2, start: 0, end: 2, codeLine: 3 },
    { title: '读取队头，不删除', explanation: 'front() 返回 1；读取之后队列内容不变。先检查 empty()，防止对空队列操作。', operation: 'front() → 1', cells: ['1','2','3'], active: 0, start: 0, end: 2, codeLine: 5 },
    { title: '移除最早的元素', explanation: 'pop() 不返回元素，它只移除队头。1 离开后，2 成为新的队头。', operation: 'pop()；队列变成 2 → 3', cells: ['2','3'], active: 0, start: 0, end: 1, codeLine: 6 }
  ]
};
const STACK: VisualLesson = {
  id: 'stack', kind: 'stack', title: '栈 · 后进先出', summary: '在栈顶压入与弹出。最后压入的元素最先离开，常见于括号匹配、深度优先搜索和撤销记录。',
  invariant: '只能通过栈顶访问元素。top() 读取，pop() 移除；两者都要求栈非空。',
  sourceTitle: 'cppreference · std::stack', sourceUrl: 'https://en.cppreference.com/w/cpp/container/stack.html',
  code: ['std::stack<int> s;', 's.push(1);', 's.push(2);', 's.push(3);',
    'if (!s.empty()) {', '  int value = s.top(); // 3', '  s.pop();', '}'],
  steps: [
    { title: '空栈', explanation: '栈底在下，栈顶在上。空栈不能读取 top() 或执行 pop()。', operation: 'stack = []', cells: [], active: -1, start: -1, end: -1, codeLine: 0 },
    { title: '压入 1', explanation: '1 成为第一个元素，处于栈底，同时也是栈顶。', operation: 'push(1)', cells: ['1'], active: 0, start: 0, end: -1, codeLine: 1 },
    { title: '在 1 上方压入 2', explanation: '2 是新的栈顶。不能越过 2 直接弹出 1。', operation: 'push(2)', cells: ['1','2'], active: 1, start: 1, end: -1, codeLine: 2 },
    { title: '再压入 3', explanation: '3 最后进入，因此它会最先被弹出。', operation: 'push(3)', cells: ['1','2','3'], active: 2, start: 2, end: -1, codeLine: 3 },
    { title: '只读取栈顶', explanation: 'top() 返回 3，并不删除它。代码先检查 empty()，再安全读取。', operation: 'top() → 3', cells: ['1','2','3'], active: 2, start: 2, end: -1, codeLine: 5 },
    { title: '弹出 3', explanation: 'pop() 不返回值，只移除栈顶。现在 2 成为栈顶；这体现了后进先出。', operation: 'pop()；栈顶变成 2', cells: ['1','2'], active: 1, start: 1, end: -1, codeLine: 6 }
  ]
};
export const VISUAL_LESSONS: VisualLesson[] = [RING, QUEUE, STACK];
export function visualLesson(id: string): VisualLesson { return VISUAL_LESSONS.find((lesson: VisualLesson) => lesson.id === id) || RING; }
export function lessonFrame(id: string, step: number): LessonStep {
  const lesson: VisualLesson = visualLesson(id);
  const index: number = Math.max(0, Math.min(lesson.steps.length - 1, Math.floor(step) || 0));
  return lesson.steps[index];
}
