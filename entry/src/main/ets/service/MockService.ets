import { SpaceInfo, TaskStatus, ThemeModeOption, TodayTask, UserSettings, UserStats } from '../model/Models';

const SPACES: SpaceInfo[] = [
  {
    spaceId: 'space_ds',
    name: '数据结构与算法',
    goal: '掌握栈、队列、链表等核心结构，能独立实现并解释差异',
    progress: 62,
    nodeCount: 12,
    completedNodeCount: 7,
    lastNodeName: '栈与队列的对比',
    lastLearnedAt: '2026-10-17 21:15',
    isArchived: false,
    coverColor: '#4C5FD5'
  },
  {
    spaceId: 'space_hm',
    name: 'HarmonyOS应用开发',
    goal: '完成一个可运行的鸿蒙学习工作台应用',
    progress: 35,
    nodeCount: 10,
    completedNodeCount: 3,
    lastNodeName: 'Navigation 路由与页面栈',
    lastLearnedAt: '2026-10-16 20:00',
    isArchived: false,
    coverColor: '#2E9E6B'
  },
  {
    spaceId: 'space_en',
    name: '考研英语词汇',
    goal: '掌握核心3000词，能读懂长难句',
    progress: 48,
    nodeCount: 8,
    completedNodeCount: 4,
    lastNodeName: '词根 spect 系列',
    lastLearnedAt: '2026-10-15 08:30',
    isArchived: false,
    coverColor: '#C2762E'
  },
  {
    spaceId: 'space_la',
    name: '线性代数入门',
    goal: '理解行列式与矩阵的基本概念',
    progress: 20,
    nodeCount: 9,
    completedNodeCount: 2,
    lastNodeName: '行列式的几何意义',
    lastLearnedAt: '2026-09-28 19:00',
    isArchived: true,
    coverColor: '#8A5AC2'
  }
];

const TODAY_TASKS: TodayTask[] = [
  {
    taskId: 'task_100',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    title: '阅读栈的实现章节',
    timeRange: '07:30-07:40',
    durationMinutes: 10,
    status: TaskStatus.Done,
    output: '完成章节笔记'
  },
  {
    taskId: 'task_101',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    title: '栈与队列对比练习',
    timeRange: '19:00-19:45',
    durationMinutes: 45,
    status: TaskStatus.InProgress,
    output: '完成一次 A/B/C 对比实验并保存记录'
  },
  {
    taskId: 'task_102',
    spaceId: 'space_hm',
    spaceName: 'HarmonyOS应用开发',
    title: '实现首页布局与导航',
    timeRange: '20:00-20:45',
    durationMinutes: 45,
    status: TaskStatus.NotStarted,
    output: '四个主页面 Tab 可切换'
  },
  {
    taskId: 'task_103',
    spaceId: 'space_en',
    spaceName: '考研英语词汇',
    title: '复习词根 spect 系列',
    timeRange: '21:00-21:15',
    durationMinutes: 15,
    status: TaskStatus.NotStarted,
    output: '完成15个词汇自测'
  }
];

const USER_STATS: UserStats = {
  streakDays: 6,
  totalLearnMinutes: 1840,
  weekLearnMinutes: 315,
  completedTaskCount: 42,
  totalTaskCount: 60,
  reviewCount: 3,
  recordCount: 18
};

let userSettings: UserSettings = {
  themeMode: ThemeModeOption.FollowSystem,
  reduceMotion: false,
  dailyTargetMinutes: 120,
  focusMinutes: 45,
  restMinutes: 10
};

export class MockService {
  static async getSpacesFiltered(keyword: string, includeArchived: boolean): Promise<SpaceInfo[]> {
    const trimmed = keyword.trim();
    const result: SpaceInfo[] = [];
    for (let i = 0; i < SPACES.length; i++) {
      const space = SPACES[i];
      if (!includeArchived && space.isArchived) {
        continue;
      }
      if (trimmed !== '' && space.name.indexOf(trimmed) < 0 && space.goal.indexOf(trimmed) < 0) {
        continue;
      }
      result.push(space);
    }
    return result;
  }

  static async getRecentSpace(): Promise<SpaceInfo | null> {
    let recent: SpaceInfo | null = null;
    for (let i = 0; i < SPACES.length; i++) {
      const space = SPACES[i];
      if (space.isArchived) {
        continue;
      }
      if (recent === null || space.lastLearnedAt > recent.lastLearnedAt) {
        recent = space;
      }
    }
    return recent;
  }

  static async archiveSpace(spaceId: string, archived: boolean): Promise<boolean> {
    for (let i = 0; i < SPACES.length; i++) {
      if (SPACES[i].spaceId === spaceId) {
        SPACES[i].isArchived = archived;
        return true;
      }
    }
    return false;
  }

  static async getTodayTasks(): Promise<TodayTask[]> {
    return TODAY_TASKS;
  }

  static async getUserStats(): Promise<UserStats> {
    return USER_STATS;
  }

  static async getSettings(): Promise<UserSettings> {
    return userSettings;
  }

  static async saveSettings(settings: UserSettings): Promise<void> {
    userSettings = settings;
  }
}
