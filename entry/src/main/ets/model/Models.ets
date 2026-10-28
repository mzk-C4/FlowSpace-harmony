export enum TaskStatus {
  NotStarted = 0,
  InProgress = 1,
  Done = 2
}

export enum ThemeModeOption {
  FollowSystem = 0,
  Light = 1,
  Dark = 2
}

export interface SpaceInfo {
  spaceId: string;
  name: string;
  goal: string;
  progress: number;
  nodeCount: number;
  completedNodeCount: number;
  lastNodeName: string;
  lastLearnedAt: string;
  isArchived: boolean;
  coverColor: string;
}

export interface TodayTask {
  taskId: string;
  spaceId: string;
  spaceName: string;
  title: string;
  timeRange: string;
  durationMinutes: number;
  status: TaskStatus;
  output: string;
}

export interface UserStats {
  streakDays: number;
  totalLearnMinutes: number;
  weekLearnMinutes: number;
  completedTaskCount: number;
  totalTaskCount: number;
  reviewCount: number;
  recordCount: number;
}

export interface UserSettings {
  themeMode: ThemeModeOption;
  reduceMotion: boolean;
  dailyTargetMinutes: number;
  focusMinutes: number;
  restMinutes: number;
}

export interface SpaceListResult {
  openMap: boolean;
  spaceId: string;
}

// ── 时间安排模块（11–14、17、19）共用的数据形状 ──

// 统一模拟数据中的“今天”，页面与 service 共用，避免日期判断各写一份
export const MOCK_TODAY: string = '2026-10-18';

export interface TaskChecklistItem {
  itemId: string;
  text: string;
  minutes: number;
  done: boolean;
}

export interface LearningTask {
  taskId: string;
  spaceId: string;
  spaceName: string;
  title: string;
  date: string;
  weekday: string;
  timeRange: string;
  durationMinutes: number;
  status: TaskStatus;
  output: string;
  checklist: TaskChecklistItem[];
  nodeIds: string[];
  nodeNames: string[];
}

export interface LifeReservedBlock {
  blockId: string;
  date: string;
  label: string;
  timeRange: string;
  durationMinutes: number;
}

export interface DayPlan {
  date: string;
  weekday: string;
  isToday: boolean;
  tasks: LearningTask[];
  lifeBlocks: LifeReservedBlock[];
  totalMinutes: number;
  reservedMinutes: number;
  dailyLimitMinutes: number;
}

export interface SpaceTimeline {
  space: SpaceInfo | null;
  spaceName: string;
  goal: string;
  days: DayPlan[];
  dailyLimitMinutes: number;
  planVersion: number;
  hasSnapshot: boolean;
}

export interface SpaceScheduleSummary {
  spaceId: string;
  spaceName: string;
  coverColor: string;
  weekTaskCount: number;
  weekMinutes: number;
  todayTaskCount: number;
  nextTaskTitle: string;
  nextTaskLabel: string;
}

export interface ScheduleOverview {
  days: DayPlan[];
  spaceSummaries: SpaceScheduleSummary[];
  dailyLimitMinutes: number;
  planVersion: number;
  todayStudyMinutes: number;
  todayReservedMinutes: number;
}

export interface PlanAdjustItem {
  itemId: string;
  title: string;
  action: string;
  beforeTimeRange: string;
  beforeMinutes: number;
  afterTimeRange: string;
  afterMinutes: number;
  detail: string;
}

export interface PlanAdjustPreview {
  previewId: string;
  planVersion: number;
  spaceId: string;
  spaceName: string;
  taskId: string;
  taskTitle: string;
  taskTimeRange: string;
  taskDurationMinutes: number;
  targetDate: string;
  targetDayLabel: string;
  reduceMinutes: number;
  reason: string;
  items: PlanAdjustItem[];
  warnings: string[];
  errors: string[];
  beforeDailyMinutes: number;
  afterDailyMinutes: number;
  beforeTargetDailyMinutes: number;
  afterTargetDailyMinutes: number;
  dailyLimitMinutes: number;
}

export interface ActionResult {
  ok: boolean;
  message: string;
}

export interface TaskBeforeState {
  taskId: string;
  title: string;
  timeRange: string;
  durationMinutes: number;
  output: string;
  checklist: TaskChecklistItem[];
}

export interface PlanSnapshot {
  snapshotId: string;
  spaceId: string;
  spaceName: string;
  createdAt: string;
  reason: string;
  versionBefore: number;
  versionAfter: number;
  originalTask: TaskBeforeState;
  afterChecklist: TaskChecklistItem[];
  createdTaskIds: string[];
  afterTaskStatus: TaskStatus;
}

export enum ReviewStatus {
  Pending = 0,
  Scheduled = 1,
  Done = 2
}

export interface ReviewItem {
  reviewId: string;
  spaceId: string;
  spaceName: string;
  nodeId: string;
  nodeName: string;
  recordId: string;
  kind: string;
  title: string;
  note: string;
  addedAt: string;
  status: ReviewStatus;
  scheduledDate: string;
  scheduledTimeRange: string;
  taskId: string;
}

export interface ReviewCandidate {
  candidateId: string;
  spaceId: string;
  spaceName: string;
  nodeId: string;
  nodeName: string;
  recordId: string;
  kind: string;
  title: string;
  note: string;
  added: boolean;
}

export interface ProjectLink {
  linkId: string;
  spaceId: string;
  spaceName: string;
  nodeId: string;
  nodeName: string;
  featureName: string;
  featureDesc: string;
  implementation: string;
  materialTitle: string;
  materialBody: string;
  materialSource: string;
  practice: string;
}

export function taskStatusText(status: TaskStatus): string {
  switch (status) {
    case TaskStatus.NotStarted:
      return '待开始';
    case TaskStatus.InProgress:
      return '进行中';
    case TaskStatus.Done:
      return '已完成';
    default:
      return '未知';
  }
}

export function taskStatusKind(status: TaskStatus): string {
  switch (status) {
    case TaskStatus.InProgress:
      return 'blue';
    case TaskStatus.Done:
      return 'green';
    case TaskStatus.NotStarted:
    default:
      return 'gray';
  }
}

export function formatMinutes(minutes: number): string {
  if (minutes < 60) {
    return minutes + '分钟';
  }
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (rest === 0) {
    return hours + '小时';
  }
  return hours + '小时' + rest + '分钟';
}

export function formatLearnedAt(text: string): string {
  if (text.length < 11) {
    return text;
  }
  const datePart = text.substring(5, 10);
  const timePart = text.substring(11);
  return datePart.replace('-', '月') + '日 ' + timePart;
}

export function reviewStatusText(status: ReviewStatus): string {
  switch (status) {
    case ReviewStatus.Scheduled:
      return '已排期';
    case ReviewStatus.Done:
      return '已复习';
    case ReviewStatus.Pending:
    default:
      return '未排期';
  }
}

export function reviewStatusKind(status: ReviewStatus): string {
  switch (status) {
    case ReviewStatus.Scheduled:
      return 'blue';
    case ReviewStatus.Done:
      return 'green';
    case ReviewStatus.Pending:
    default:
      return 'gray';
  }
}

export function shortDateLabel(date: string): string {
  if (date.length < 10) {
    return date;
  }
  return date.substring(5, 7) + '/' + date.substring(8, 10);
}

export function formatDateLabel(date: string): string {
  if (date.length < 10) {
    return date;
  }
  return date.substring(5, 7) + '月' + date.substring(8, 10) + '日';
}
