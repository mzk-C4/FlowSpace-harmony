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
