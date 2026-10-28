import {
  ActionResult,
  DayPlan,
  LearningTask,
  LifeReservedBlock,
  MOCK_TODAY,
  PlanAdjustItem,
  PlanAdjustPreview,
  PlanSnapshot,
  ProjectLink,
  ReviewCandidate,
  ReviewItem,
  ReviewStatus,
  ScheduleOverview,
  SpaceInfo,
  SpaceScheduleSummary,
  SpaceTimeline,
  TaskBeforeState,
  TaskChecklistItem,
  TaskStatus,
  ThemeModeOption,
  TodayTask,
  UserSettings,
  UserStats,
  formatDateLabel
} from '../model/Models';

const TODAY = MOCK_TODAY;
const DAILY_LIMIT_MINUTES = 120;

interface PlanDayInfo {
  date: string;
  weekday: string;
}

const PLAN_DAYS: PlanDayInfo[] = [
  { date: '2026-10-18', weekday: '周日' },
  { date: '2026-10-19', weekday: '周一' },
  { date: '2026-10-20', weekday: '周二' },
  { date: '2026-10-21', weekday: '周三' },
  { date: '2026-10-22', weekday: '周四' },
  { date: '2026-10-23', weekday: '周五' },
  { date: '2026-10-24', weekday: '周六' }
];

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

const PLAN_TASKS: LearningTask[] = [
  {
    taskId: 'task_100',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    title: '阅读栈的实现章节',
    date: '2026-10-18',
    weekday: '周日',
    timeRange: '07:30-07:40',
    durationMinutes: 10,
    status: TaskStatus.Done,
    output: '完成章节笔记',
    checklist: [
      { itemId: 'task_100_1', text: '读完 1.2 节', minutes: 6, done: true },
      { itemId: 'task_100_2', text: '摘录 3 条要点', minutes: 4, done: true }
    ],
    nodeIds: ['node_stack'],
    nodeNames: ['栈与队列的对比']
  },
  {
    taskId: 'task_101',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    title: '栈与队列对比练习',
    date: '2026-10-18',
    weekday: '周日',
    timeRange: '19:00-19:45',
    durationMinutes: 45,
    status: TaskStatus.InProgress,
    output: '完成一次 A/B/C 对比实验并保存记录',
    checklist: [
      { itemId: 'task_101_1', text: '预测栈的取出顺序', minutes: 5, done: true },
      { itemId: 'task_101_2', text: '预测队列的取出顺序', minutes: 5, done: true },
      { itemId: 'task_101_3', text: '运行并记录结果', minutes: 15, done: false },
      { itemId: 'task_101_4', text: '写下差异解释', minutes: 10, done: false },
      { itemId: 'task_101_5', text: '提交前检查', minutes: 10, done: false }
    ],
    nodeIds: ['node_stack', 'node_queue'],
    nodeNames: ['栈与队列的对比', '队列']
  },
  {
    taskId: 'task_102',
    spaceId: 'space_hm',
    spaceName: 'HarmonyOS应用开发',
    title: '实现首页布局与导航',
    date: '2026-10-18',
    weekday: '周日',
    timeRange: '20:00-20:45',
    durationMinutes: 45,
    status: TaskStatus.NotStarted,
    output: '四个主页面 Tab 可切换',
    checklist: [
      { itemId: 'task_102_1', text: '搭出首页骨架', minutes: 20, done: false },
      { itemId: 'task_102_2', text: '接入底部导航', minutes: 15, done: false },
      { itemId: 'task_102_3', text: '检查四个 Tab 可切换', minutes: 10, done: false }
    ],
    nodeIds: ['node_arkui', 'node_nav'],
    nodeNames: ['ArkUI 布局', 'Navigation 路由与页面栈']
  },
  {
    taskId: 'task_103',
    spaceId: 'space_en',
    spaceName: '考研英语词汇',
    title: '复习词根 spect 系列',
    date: '2026-10-18',
    weekday: '周日',
    timeRange: '21:00-21:15',
    durationMinutes: 15,
    status: TaskStatus.NotStarted,
    output: '完成15个词汇自测',
    checklist: [
      { itemId: 'task_103_1', text: '自测 15 个词', minutes: 10, done: false },
      { itemId: 'task_103_2', text: '标出陌生词', minutes: 5, done: false }
    ],
    nodeIds: ['node_spect'],
    nodeNames: ['词根 spect 系列']
  },
  {
    taskId: 'task_104',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    title: '链表与数组对比练习',
    date: '2026-10-19',
    weekday: '周一',
    timeRange: '19:00-19:45',
    durationMinutes: 45,
    status: TaskStatus.NotStarted,
    output: '完成一张链表与数组对比表',
    checklist: [
      { itemId: 'task_104_1', text: '整理插入与删除差异', minutes: 20, done: false },
      { itemId: 'task_104_2', text: '完成对比表', minutes: 20, done: false },
      { itemId: 'task_104_3', text: '复查并补一条示例', minutes: 5, done: false }
    ],
    nodeIds: ['node_list'],
    nodeNames: ['链表']
  },
  {
    taskId: 'task_105',
    spaceId: 'space_hm',
    spaceName: 'HarmonyOS应用开发',
    title: '完成状态管理练习',
    date: '2026-10-19',
    weekday: '周一',
    timeRange: '20:00-20:30',
    durationMinutes: 30,
    status: TaskStatus.NotStarted,
    output: '点击加一计数器可交互',
    checklist: [
      { itemId: 'task_105_1', text: '写一个 @State 计数器', minutes: 15, done: false },
      { itemId: 'task_105_2', text: '解释状态驱动界面的过程', minutes: 15, done: false }
    ],
    nodeIds: ['node_state'],
    nodeNames: ['状态管理']
  },
  {
    taskId: 'task_106',
    spaceId: 'space_en',
    spaceName: '考研英语词汇',
    title: '背诵词根 dict 系列',
    date: '2026-10-19',
    weekday: '周一',
    timeRange: '07:30-07:50',
    durationMinutes: 20,
    status: TaskStatus.NotStarted,
    output: '默写20个单词',
    checklist: [
      { itemId: 'task_106_1', text: '过一遍词根表', minutes: 10, done: false },
      { itemId: 'task_106_2', text: '默写并核对', minutes: 10, done: false }
    ],
    nodeIds: ['node_dict'],
    nodeNames: ['词根 dict 系列']
  },
  {
    taskId: 'task_107',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    title: '完成递归练习',
    date: '2026-10-20',
    weekday: '周二',
    timeRange: '19:00-19:45',
    durationMinutes: 45,
    status: TaskStatus.NotStarted,
    output: '3 道递归题通过',
    checklist: [
      { itemId: 'task_107_1', text: '写出终止条件', minutes: 10, done: false },
      { itemId: 'task_107_2', text: '完成 3 道题', minutes: 30, done: false },
      { itemId: 'task_107_3', text: '记录一处易错点', minutes: 5, done: false }
    ],
    nodeIds: ['node_recursion'],
    nodeNames: ['递归']
  },
  {
    taskId: 'task_108',
    spaceId: 'space_hm',
    spaceName: 'HarmonyOS应用开发',
    title: '实现任务列表页',
    date: '2026-10-20',
    weekday: '周二',
    timeRange: '20:00-20:45',
    durationMinutes: 45,
    status: TaskStatus.NotStarted,
    output: '任务列表可滚动查看',
    checklist: [
      { itemId: 'task_108_1', text: '用 List 搭出列表', minutes: 20, done: false },
      { itemId: 'task_108_2', text: '接上模拟任务数据', minutes: 20, done: false },
      { itemId: 'task_108_3', text: '检查滚动与空态', minutes: 5, done: false }
    ],
    nodeIds: ['node_arkui'],
    nodeNames: ['ArkUI 布局']
  },
  {
    taskId: 'task_109',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    title: '整理栈与队列笔记',
    date: '2026-10-21',
    weekday: '周三',
    timeRange: '19:00-19:30',
    durationMinutes: 30,
    status: TaskStatus.NotStarted,
    output: '一页栈与队列对比笔记',
    checklist: [
      { itemId: 'task_109_1', text: '整理取出顺序差异', minutes: 15, done: false },
      { itemId: 'task_109_2', text: '补一个生活例子', minutes: 15, done: false }
    ],
    nodeIds: ['node_stack', 'node_queue'],
    nodeNames: ['栈与队列的对比', '队列']
  },
  {
    taskId: 'task_110',
    spaceId: 'space_en',
    spaceName: '考研英语词汇',
    title: '复习词根 spect',
    date: '2026-10-21',
    weekday: '周三',
    timeRange: '07:30-07:45',
    durationMinutes: 15,
    status: TaskStatus.NotStarted,
    output: '10 个词自测',
    checklist: [
      { itemId: 'task_110_1', text: '自测 10 个词', minutes: 10, done: false },
      { itemId: 'task_110_2', text: '订正错误', minutes: 5, done: false }
    ],
    nodeIds: ['node_spect'],
    nodeNames: ['词根 spect 系列']
  },
  {
    taskId: 'task_111',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    title: '队列应用练习',
    date: '2026-10-22',
    weekday: '周四',
    timeRange: '19:30-20:15',
    durationMinutes: 45,
    status: TaskStatus.NotStarted,
    output: '完成打印机队列模拟',
    checklist: [
      { itemId: 'task_111_1', text: '设计队列数据结构', minutes: 15, done: false },
      { itemId: 'task_111_2', text: '模拟打印任务出队', minutes: 25, done: false },
      { itemId: 'task_111_3', text: '检查取出顺序', minutes: 5, done: false }
    ],
    nodeIds: ['node_queue'],
    nodeNames: ['队列']
  },
  {
    taskId: 'task_112',
    spaceId: 'space_hm',
    spaceName: 'HarmonyOS应用开发',
    title: '页面导航练习',
    date: '2026-10-22',
    weekday: '周四',
    timeRange: '20:30-21:00',
    durationMinutes: 30,
    status: TaskStatus.NotStarted,
    output: '完成三个页面跳转',
    checklist: [
      { itemId: 'task_112_1', text: '配置路由表', minutes: 15, done: false },
      { itemId: 'task_112_2', text: '验证返回与参数', minutes: 15, done: false }
    ],
    nodeIds: ['node_nav'],
    nodeNames: ['Navigation 路由与页面栈']
  },
  {
    taskId: 'task_113',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    title: '综合复习：栈与队列',
    date: '2026-10-23',
    weekday: '周五',
    timeRange: '20:30-21:15',
    durationMinutes: 45,
    status: TaskStatus.NotStarted,
    output: '完成自测并记录疑问',
    checklist: [
      { itemId: 'task_113_1', text: '完成 10 道自测', minutes: 25, done: false },
      { itemId: 'task_113_2', text: '记录仍存在的疑问', minutes: 10, done: false },
      { itemId: 'task_113_3', text: '加入复习清单', minutes: 10, done: false }
    ],
    nodeIds: ['node_stack', 'node_queue'],
    nodeNames: ['栈与队列的对比', '队列']
  },
  {
    taskId: 'task_114',
    spaceId: 'space_en',
    spaceName: '考研英语词汇',
    title: '长难句拆解',
    date: '2026-10-23',
    weekday: '周五',
    timeRange: '07:30-07:50',
    durationMinutes: 20,
    status: TaskStatus.NotStarted,
    output: '完成 5 句拆解',
    checklist: [
      { itemId: 'task_114_1', text: '拆解 5 个长句', minutes: 15, done: false },
      { itemId: 'task_114_2', text: '标注主谓宾', minutes: 5, done: false }
    ],
    nodeIds: ['node_spect'],
    nodeNames: ['词根 spect 系列']
  },
  {
    taskId: 'task_115',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    title: '本周错题回顾',
    date: '2026-10-24',
    weekday: '周六',
    timeRange: '10:00-10:30',
    durationMinutes: 30,
    status: TaskStatus.NotStarted,
    output: '整理 3 条错因',
    checklist: [
      { itemId: 'task_115_1', text: '翻看本周错题', minutes: 15, done: false },
      { itemId: 'task_115_2', text: '写下 3 条错因', minutes: 15, done: false }
    ],
    nodeIds: ['node_stack', 'node_recursion'],
    nodeNames: ['栈与队列的对比', '递归']
  },
  {
    taskId: 'task_116',
    spaceId: 'space_hm',
    spaceName: 'HarmonyOS应用开发',
    title: '首页联调',
    date: '2026-10-24',
    weekday: '周六',
    timeRange: '10:40-11:25',
    durationMinutes: 45,
    status: TaskStatus.NotStarted,
    output: '首页与导航联通',
    checklist: [
      { itemId: 'task_116_1', text: '串联首页入口', minutes: 25, done: false },
      { itemId: 'task_116_2', text: '检查返回路径', minutes: 20, done: false }
    ],
    nodeIds: ['node_arkui', 'node_nav'],
    nodeNames: ['ArkUI 布局', 'Navigation 路由与页面栈']
  }
];

const REVIEW_CANDIDATES: ReviewCandidate[] = [
  {
    candidateId: 'cand_1',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    nodeId: 'node_stack',
    nodeName: '栈与队列的对比',
    recordId: 'rec_201',
    kind: '疑问',
    title: '为什么栈的取出顺序和队列相反？',
    note: '对比练习中预测错了，想再解释一次',
    added: true
  },
  {
    candidateId: 'cand_2',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    nodeId: 'node_recursion',
    nodeName: '递归',
    recordId: 'rec_202',
    kind: '练习',
    title: '递归终止条件总写错',
    note: '第 3 题没有写终止条件导致栈溢出',
    added: true
  },
  {
    candidateId: 'cand_3',
    spaceId: 'space_hm',
    spaceName: 'HarmonyOS应用开发',
    nodeId: 'node_nav',
    nodeName: 'Navigation 路由与页面栈',
    recordId: 'rec_203',
    kind: '疑问',
    title: 'pushPath 和 replacePath 的区别',
    note: '返回时页面栈的变化还不清楚',
    added: true
  },
  {
    candidateId: 'cand_4',
    spaceId: 'space_hm',
    spaceName: 'HarmonyOS应用开发',
    nodeId: 'node_state',
    nodeName: '状态管理',
    recordId: 'rec_204',
    kind: '练习',
    title: '为什么普通变量改了界面不刷新？',
    note: '练习题里漏了 @State',
    added: false
  }
];

const REVIEW_ITEMS: ReviewItem[] = [
  {
    reviewId: 'review_101',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    nodeId: 'node_stack',
    nodeName: '栈与队列的对比',
    recordId: 'rec_201',
    kind: '疑问',
    title: '为什么栈的取出顺序和队列相反？',
    note: '对比练习中预测错了，想再解释一次',
    addedAt: '2026-10-16 21:20',
    status: ReviewStatus.Pending,
    scheduledDate: '',
    scheduledTimeRange: '',
    taskId: ''
  },
  {
    reviewId: 'review_102',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    nodeId: 'node_recursion',
    nodeName: '递归',
    recordId: 'rec_202',
    kind: '练习',
    title: '递归终止条件总写错',
    note: '第 3 题没有写终止条件导致栈溢出',
    addedAt: '2026-10-17 20:10',
    status: ReviewStatus.Pending,
    scheduledDate: '',
    scheduledTimeRange: '',
    taskId: ''
  },
  {
    reviewId: 'review_103',
    spaceId: 'space_hm',
    spaceName: 'HarmonyOS应用开发',
    nodeId: 'node_nav',
    nodeName: 'Navigation 路由与页面栈',
    recordId: 'rec_203',
    kind: '疑问',
    title: 'pushPath 和 replacePath 的区别',
    note: '返回时页面栈的变化还不清楚',
    addedAt: '2026-10-17 22:05',
    status: ReviewStatus.Pending,
    scheduledDate: '',
    scheduledTimeRange: '',
    taskId: ''
  }
];

const PROJECT_LINKS: ProjectLink[] = [
  {
    linkId: 'link_1',
    spaceId: 'space_hm',
    spaceName: 'HarmonyOS应用开发',
    nodeId: 'node_arkui',
    nodeName: 'ArkUI 布局',
    featureName: '首页空间卡片',
    featureDesc: '把学习空间按卡片横向排列，点开进入对应空间。',
    implementation: '用 Row 做横向容器，Column 叠放标题、目标和进度条；卡片统一 16 圆角与间距，保证手机和平板都不裁切。',
    materialTitle: 'ArkUI 官方布局文档',
    materialBody: 'Column 负责竖排、Row 负责横排，padding 控制内边距，layoutWeight 让子元素按比例分配剩余空间。',
    materialSource: 'ArkUI 官方布局文档（开发者联盟）',
    practice: '用 Column/Row 搭出课程卡片，并说明 padding 和 margin 的区别。'
  },
  {
    linkId: 'link_2',
    spaceId: 'space_hm',
    spaceName: 'HarmonyOS应用开发',
    nodeId: 'node_nav',
    nodeName: 'Navigation 路由与页面栈',
    featureName: '页面跳转与返回',
    featureDesc: '首页、安排总览、时间轴和任务详情之间可以带着参数跳转并返回。',
    implementation: '用 Navigation + NavPathStack 管理页面栈，pushPathByName 携带 taskId 或 spaceId；详情页在 onReady 读取参数，返回时恢复原页面。',
    materialTitle: 'Router 导航开发指南',
    materialBody: 'pushUrl 可以携带参数，详情页根据参数显示对应内容；返回时页面栈按后进先出恢复。',
    materialSource: 'Navigation 开发指南（开发者联盟）',
    practice: '实现点任务跳详情并带上 taskId，再验证返回后仍在原日期。'
  },
  {
    linkId: 'link_3',
    spaceId: 'space_hm',
    spaceName: 'HarmonyOS应用开发',
    nodeId: 'node_state',
    nodeName: '状态管理',
    featureName: '今日任务状态同步',
    featureDesc: '开始或完成任务后，首页、安排总览和时间轴显示同一个状态。',
    implementation: '服务层保存唯一任务数据源，页面用 @State 接收结果并重新读取；状态变化后所有视图重新取数，不各自维护副本。',
    materialTitle: 'ArkUI 状态管理官方文档',
    materialBody: '给变量加 @State 后，数据变化会驱动使用它的界面重新渲染；跨页面共享数据应放在统一的 service 层。',
    materialSource: 'ArkUI 状态管理官方文档',
    practice: '做一个点击加一的计数器，并解释 @State 为什么能驱动界面。'
  },
  {
    linkId: 'link_4',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    nodeId: 'node_stack',
    nodeName: '栈与队列的对比',
    featureName: '概念对比台',
    featureDesc: '用同一组 A/B/C 输入观察栈和队列的取出顺序差异。',
    implementation: '栈用数组尾部入栈和出栈，队列用数组头部出队；运行结果按数据值记录，预测值单独保存，两者分开显示。',
    materialTitle: '栈与队列对比练习',
    materialBody: '栈后进先出，先取出 C；队列先进先出，先取出 A。剩余元素分别是 B/A 和 B/C。',
    materialSource: '数据结构课程讲义第 3 章',
    practice: '输入 A/B/C，先预测再运行，把差异写进个人解释。'
  },
  {
    linkId: 'link_5',
    spaceId: 'space_ds',
    spaceName: '数据结构与算法',
    nodeId: 'node_recursion',
    nodeName: '递归',
    featureName: '知识地图层级展开',
    featureDesc: '目标拆成知识点时，用递归结构逐层展开前置知识。',
    implementation: '每个知识节点保存前置节点 ID，展开时递归读取子节点；设置最大展开层级，避免环形关系导致重复渲染。',
    materialTitle: '知识地图构建说明',
    materialBody: '前置知识关系形成有向图，展开时按层级遍历；需要记录已访问节点，避免环。',
    materialSource: '课程项目需求说明（样例补充）',
    practice: '为三个知识点画出前置关系，并检查是否会形成环。'
  }
];

let userSettings: UserSettings = {
  themeMode: ThemeModeOption.FollowSystem,
  reduceMotion: false,
  dailyTargetMinutes: 120,
  focusMinutes: 45,
  restMinutes: 10
};

const USER_STATS: UserStats = {
  streakDays: 6,
  totalLearnMinutes: 1840,
  weekLearnMinutes: 315,
  completedTaskCount: 42,
  totalTaskCount: 60,
  reviewCount: 3,
  recordCount: 18
};

let planVersion: number = 3;
let previewSeq: number = 1;
let snapshotSeq: number = 1;
let nextTaskSeq: number = 300;
let nextReviewSeq: number = 200;
let PREVIEWS: PlanAdjustPreview[] = [];
let SNAPSHOTS: PlanSnapshot[] = [];

function toNumber(text: string): number {
  let value = 0;
  for (let i = 0; i < text.length; i++) {
    const code = text.charCodeAt(i) - 48;
    if (code >= 0 && code <= 9) {
      value = value * 10 + code;
    }
  }
  return value;
}

function twoDigits(value: number): string {
  return value < 10 ? '0' + value : '' + value;
}

function timeToMinutes(hhmm: string): number {
  const hour = toNumber(hhmm.substring(0, 2));
  const minute = toNumber(hhmm.substring(3, 5));
  return hour * 60 + minute;
}

function minutesToClock(minutes: number): string {
  return twoDigits(Math.floor(minutes / 60)) + ':' + twoDigits(minutes % 60);
}

function rangeStart(range: string): number {
  return timeToMinutes(range.substring(0, 5));
}

function rangeEnd(range: string): number {
  return timeToMinutes(range.substring(6, 11));
}

function overlaps(aStart: number, aEnd: number, bStart: number, bEnd: number): boolean {
  return aStart < bEnd && bStart < aEnd;
}

function weekdayOf(date: string): string {
  for (let i = 0; i < PLAN_DAYS.length; i++) {
    if (PLAN_DAYS[i].date === date) {
      return PLAN_DAYS[i].weekday;
    }
  }
  return '';
}

function lifeBlocksOf(date: string): LifeReservedBlock[] {
  const blocks: LifeReservedBlock[] = [
    { blockId: 'life_' + date + '_1', date: date, label: '早餐', timeRange: '07:00-07:30', durationMinutes: 30 },
    { blockId: 'life_' + date + '_2', date: date, label: '午饭与午休', timeRange: '12:00-13:00', durationMinutes: 60 },
    { blockId: 'life_' + date + '_3', date: date, label: '晚饭', timeRange: '18:00-19:00', durationMinutes: 60 },
    { blockId: 'life_' + date + '_4', date: date, label: '洗漱休息', timeRange: '22:30-23:00', durationMinutes: 30 }
  ];
  if (date === '2026-10-21') {
    blocks.push({
      blockId: 'life_course_wed',
      date: date,
      label: '课程（固定）',
      timeRange: '15:00-16:30',
      durationMinutes: 90
    });
  }
  if (date === '2026-10-23') {
    blocks.push({
      blockId: 'life_course_fri',
      date: date,
      label: '课程（固定）',
      timeRange: '19:00-20:30',
      durationMinutes: 90
    });
  }
  if (date === '2026-10-24') {
    blocks.push({
      blockId: 'life_family_sat',
      date: date,
      label: '家庭时间',
      timeRange: '09:00-09:45',
      durationMinutes: 45
    });
  }
  return blocks;
}

function findSpace(spaceId: string): SpaceInfo | null {
  for (let i = 0; i < SPACES.length; i++) {
    if (SPACES[i].spaceId === spaceId) {
      return SPACES[i];
    }
  }
  return null;
}

function findTask(taskId: string): LearningTask | null {
  for (let i = 0; i < PLAN_TASKS.length; i++) {
    if (PLAN_TASKS[i].taskId === taskId) {
      return PLAN_TASKS[i];
    }
  }
  return null;
}

function findReview(reviewId: string): ReviewItem | null {
  for (let i = 0; i < REVIEW_ITEMS.length; i++) {
    if (REVIEW_ITEMS[i].reviewId === reviewId) {
      return REVIEW_ITEMS[i];
    }
  }
  return null;
}

function findCandidate(candidateId: string): ReviewCandidate | null {
  for (let i = 0; i < REVIEW_CANDIDATES.length; i++) {
    if (REVIEW_CANDIDATES[i].candidateId === candidateId) {
      return REVIEW_CANDIDATES[i];
    }
  }
  return null;
}

function cloneChecklist(items: TaskChecklistItem[]): TaskChecklistItem[] {
  const result: TaskChecklistItem[] = [];
  for (let i = 0; i < items.length; i++) {
    result.push({
      itemId: items[i].itemId,
      text: items[i].text,
      minutes: items[i].minutes,
      done: items[i].done
    });
  }
  return result;
}

function cloneTask(task: LearningTask): LearningTask {
  return {
    taskId: task.taskId,
    spaceId: task.spaceId,
    spaceName: task.spaceName,
    title: task.title,
    date: task.date,
    weekday: task.weekday,
    timeRange: task.timeRange,
    durationMinutes: task.durationMinutes,
    status: task.status,
    output: task.output,
    checklist: cloneChecklist(task.checklist),
    nodeIds: task.nodeIds.slice(),
    nodeNames: task.nodeNames.slice()
  };
}

function cloneTaskBefore(task: LearningTask): TaskBeforeState {
  return {
    taskId: task.taskId,
    title: task.title,
    timeRange: task.timeRange,
    durationMinutes: task.durationMinutes,
    output: task.output,
    checklist: cloneChecklist(task.checklist)
  };
}

function buildDayPlan(date: string, weekday: string, spaceId: string): DayPlan {
  const tasks: LearningTask[] = [];
  let total = 0;
  for (let i = 0; i < PLAN_TASKS.length; i++) {
    const task = PLAN_TASKS[i];
    if (task.date !== date) {
      continue;
    }
    if (spaceId !== '' && task.spaceId !== spaceId) {
      continue;
    }
    tasks.push(task);
    total += task.durationMinutes;
  }
  tasks.sort((a: LearningTask, b: LearningTask) => rangeStart(a.timeRange) - rangeStart(b.timeRange));
  const blocks = lifeBlocksOf(date);
  let reserved = 0;
  for (let i = 0; i < blocks.length; i++) {
    reserved += blocks[i].durationMinutes;
  }
  return {
    date: date,
    weekday: weekday,
    isToday: date === TODAY,
    tasks: tasks,
    lifeBlocks: blocks,
    totalMinutes: total,
    reservedMinutes: reserved,
    dailyLimitMinutes: DAILY_LIMIT_MINUTES
  };
}

function buildDays(spaceId: string): DayPlan[] {
  const days: DayPlan[] = [];
  for (let i = 0; i < PLAN_DAYS.length; i++) {
    days.push(buildDayPlan(PLAN_DAYS[i].date, PLAN_DAYS[i].weekday, spaceId));
  }
  return days;
}

function validateSlot(date: string, startMinute: number, endMinute: number,
  excludeTaskId: string, extraMinutes: number): string[] {
  const errors: string[] = [];
  const blocks = lifeBlocksOf(date);
  for (let i = 0; i < blocks.length; i++) {
    const block = blocks[i];
    if (overlaps(startMinute, endMinute, rangeStart(block.timeRange), rangeEnd(block.timeRange))) {
      errors.push('与保留生活时间「' + block.label + '」' + block.timeRange + ' 冲突，保留时间不可占用');
    }
  }
  let baseMinutes = 0;
  for (let i = 0; i < PLAN_TASKS.length; i++) {
    const task = PLAN_TASKS[i];
    if (task.date !== date) {
      continue;
    }
    if (task.taskId === excludeTaskId) {
      continue;
    }
    baseMinutes += task.durationMinutes;
    if (overlaps(startMinute, endMinute, rangeStart(task.timeRange), rangeEnd(task.timeRange))) {
      errors.push('与任务「' + task.title + '」' + task.timeRange + ' 时间重叠');
    }
  }
  if (baseMinutes + extraMinutes > DAILY_LIMIT_MINUTES) {
    errors.push('超过每日上限：' + formatDateLabel(date) + ' 将安排 ' +
      (baseMinutes + extraMinutes) + ' 分钟 > ' + DAILY_LIMIT_MINUTES + ' 分钟');
  }
  return errors;
}

function activeSnapshotFor(spaceId: string): PlanSnapshot | null {
  let found: PlanSnapshot | null = null;
  for (let i = 0; i < SNAPSHOTS.length; i++) {
    if (SNAPSHOTS[i].spaceId === spaceId) {
      found = SNAPSHOTS[i];
    }
  }
  return found;
}

function removePreviewsForTask(taskId: string): void {
  const remaining: PlanAdjustPreview[] = [];
  for (let i = 0; i < PREVIEWS.length; i++) {
    if (PREVIEWS[i].taskId !== taskId) {
      remaining.push(PREVIEWS[i]);
    }
  }
  PREVIEWS = remaining;
}

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
    const result: TodayTask[] = [];
    for (let i = 0; i < PLAN_TASKS.length; i++) {
      const task = PLAN_TASKS[i];
      if (task.date !== TODAY) {
        continue;
      }
      result.push({
        taskId: task.taskId,
        spaceId: task.spaceId,
        spaceName: task.spaceName,
        title: task.title,
        timeRange: task.timeRange,
        durationMinutes: task.durationMinutes,
        status: task.status,
        output: task.output
      });
    }
    result.sort((a: TodayTask, b: TodayTask) => rangeStart(a.timeRange) - rangeStart(b.timeRange));
    return result;
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

  static async getSpaceTimeline(spaceId: string): Promise<SpaceTimeline> {
    const space = findSpace(spaceId);
    const snapshot = activeSnapshotFor(spaceId);
    return {
      space: space,
      spaceName: space === null ? '' : space.name,
      goal: space === null ? '' : space.goal,
      days: buildDays(spaceId),
      dailyLimitMinutes: DAILY_LIMIT_MINUTES,
      planVersion: planVersion,
      hasSnapshot: snapshot !== null
    };
  }

  static async getScheduleOverview(): Promise<ScheduleOverview> {
    const days = buildDays('');
    const summaries: SpaceScheduleSummary[] = [];
    for (let i = 0; i < SPACES.length; i++) {
      const space = SPACES[i];
      if (space.isArchived) {
        continue;
      }
      let weekTaskCount = 0;
      let weekMinutes = 0;
      let todayTaskCount = 0;
      let nextTask: LearningTask | null = null;
      for (let j = 0; j < PLAN_TASKS.length; j++) {
        const task = PLAN_TASKS[j];
        if (task.spaceId !== space.spaceId) {
          continue;
        }
        weekTaskCount += 1;
        weekMinutes += task.durationMinutes;
        if (task.date === TODAY) {
          todayTaskCount += 1;
        }
        if (task.status === TaskStatus.Done || task.date < TODAY) {
          continue;
        }
        if (nextTask === null ||
          task.date < nextTask.date ||
          (task.date === nextTask.date && rangeStart(task.timeRange) < rangeStart(nextTask.timeRange))) {
          nextTask = task;
        }
      }
      summaries.push({
        spaceId: space.spaceId,
        spaceName: space.name,
        coverColor: space.coverColor,
        weekTaskCount: weekTaskCount,
        weekMinutes: weekMinutes,
        todayTaskCount: todayTaskCount,
        nextTaskTitle: nextTask === null ? '' : nextTask.title,
        nextTaskLabel: nextTask === null ? '' : formatDateLabel(nextTask.date) + ' ' + nextTask.timeRange
      });
    }
    let todayStudyMinutes = 0;
    let todayReservedMinutes = 0;
    if (days.length > 0) {
      todayStudyMinutes = days[0].totalMinutes;
      todayReservedMinutes = days[0].reservedMinutes;
    }
    return {
      days: days,
      spaceSummaries: summaries,
      dailyLimitMinutes: DAILY_LIMIT_MINUTES,
      planVersion: planVersion,
      todayStudyMinutes: todayStudyMinutes,
      todayReservedMinutes: todayReservedMinutes
    };
  }

  static async getTaskDetail(taskId: string): Promise<LearningTask | null> {
    const task = findTask(taskId);
    if (task === null) {
      return null;
    }
    return cloneTask(task);
  }

  static async startTask(taskId: string): Promise<ActionResult> {
    const task = findTask(taskId);
    if (task === null) {
      return { ok: false, message: '任务不存在或已过期' };
    }
    if (task.status === TaskStatus.Done) {
      return { ok: false, message: '任务已经完成' };
    }
    task.status = TaskStatus.InProgress;
    return { ok: true, message: '任务已开始，完成后记得标记' };
  }

  static async completeTask(taskId: string): Promise<ActionResult> {
    const task = findTask(taskId);
    if (task === null) {
      return { ok: false, message: '任务不存在或已过期' };
    }
    task.status = TaskStatus.Done;
    for (let i = 0; i < task.checklist.length; i++) {
      task.checklist[i].done = true;
    }
    for (let i = 0; i < REVIEW_ITEMS.length; i++) {
      if (REVIEW_ITEMS[i].taskId === taskId) {
        REVIEW_ITEMS[i].status = ReviewStatus.Done;
      }
    }
    return { ok: true, message: '任务已完成；理解状态仍由你自己判断' };
  }

  static async toggleChecklistItem(taskId: string, itemId: string): Promise<boolean> {
    const task = findTask(taskId);
    if (task === null) {
      return false;
    }
    for (let i = 0; i < task.checklist.length; i++) {
      if (task.checklist[i].itemId === itemId) {
        task.checklist[i].done = !task.checklist[i].done;
        return true;
      }
    }
    return false;
  }

  static async createAdjustPreview(taskId: string, targetDate: string): Promise<PlanAdjustPreview | null> {
    const task = findTask(taskId);
    if (task === null) {
      return null;
    }
    removePreviewsForTask(taskId);
    const targetLabel = weekdayOf(targetDate);
    const targetDay = buildDayPlan(targetDate, targetLabel, '');
    const todayDay = buildDayPlan(task.date, task.weekday, '');
    const errors: string[] = [];
    const warnings: string[] = [];
    let reduceMinutes = 30;
    if (task.date !== TODAY) {
      errors.push('只有当天可用时间变化时才能预览调整，这个任务不在今天');
      reduceMinutes = 0;
    }
    if (task.durationMinutes < 45) {
      errors.push('该任务不足 45 分钟，无法按 15 + 30 的示例拆分');
      reduceMinutes = 0;
    }
    let hasCheck = false;
    let doneMinutes = 0;
    for (let i = 0; i < task.checklist.length; i++) {
      if (task.checklist[i].text.indexOf('提交前检查') >= 0) {
        hasCheck = true;
      }
      if (task.checklist[i].done) {
        doneMinutes += task.checklist[i].minutes;
      }
    }
    if (reduceMinutes > 0 && doneMinutes > task.durationMinutes - reduceMinutes) {
      errors.push('已完成清单共 ' + doneMinutes + ' 分钟，超过调整后今天保留的 ' +
        (task.durationMinutes - reduceMinutes) + ' 分钟；请先撤销部分勾选，或改为其他调整方式');
    }
    const todayStart = rangeStart(task.timeRange);
    const todayEnd = todayStart + (task.durationMinutes - reduceMinutes);
    const targetStart = 19 * 60;
    const targetEnd = targetStart + reduceMinutes;
    const targetRange = minutesToClock(targetStart) + '-' + minutesToClock(targetEnd);

    const items: PlanAdjustItem[] = [];
    items.push({
      itemId: 'adjust_' + taskId + '_1',
      title: task.title,
      action: '拆分',
      beforeTimeRange: formatDateLabel(task.date) + ' ' + task.timeRange,
      beforeMinutes: task.durationMinutes,
      afterTimeRange: formatDateLabel(task.date) + ' ' +
        minutesToClock(todayStart) + '-' + minutesToClock(todayEnd),
      afterMinutes: task.durationMinutes - reduceMinutes,
      detail: '今天先完成实验与记录，余下 ' + reduceMinutes + ' 分钟移到' + targetLabel
    });
    items.push({
      itemId: 'adjust_' + taskId + '_2',
      title: task.title + '（续）',
      action: '新增',
      beforeTimeRange: '—',
      beforeMinutes: 0,
      afterTimeRange: targetLabel + ' ' + targetRange,
      afterMinutes: reduceMinutes,
      detail: '完成结果解释与提交检查，总量不增加'
    });
    if (hasCheck) {
      items.push({
        itemId: 'adjust_' + taskId + '_3',
        title: '检查清单：提交前检查',
        action: '拆分',
        beforeTimeRange: '原 10 分钟',
        beforeMinutes: 10,
        afterTimeRange: '今天 5 分钟 + ' + targetLabel + ' 5 分钟',
        afterMinutes: 10,
        detail: '今天只做 5 分钟记录，目标日做 5 分钟检查，避免总量增加'
      });
    }

    if (reduceMinutes > 0) {
      const todayErrors = validateSlot(task.date, todayStart, todayEnd, taskId, task.durationMinutes - reduceMinutes);
      for (let i = 0; i < todayErrors.length; i++) {
        errors.push('今天：' + todayErrors[i]);
      }
      const targetErrors = validateSlot(targetDate, targetStart, targetEnd, '', reduceMinutes);
      for (let i = 0; i < targetErrors.length; i++) {
        errors.push(targetLabel + '：' + targetErrors[i]);
      }
      if (targetErrors.length === 0) {
        warnings.push(targetLabel + ' ' + targetRange + ' 已避开保留生活时间与已有任务，确认后才写入正式计划。');
      }
    }

    const preview: PlanAdjustPreview = {
      previewId: 'preview_' + previewSeq,
      planVersion: planVersion,
      spaceId: task.spaceId,
      spaceName: task.spaceName,
      taskId: task.taskId,
      taskTitle: task.title,
      taskTimeRange: task.timeRange,
      taskDurationMinutes: task.durationMinutes,
      targetDate: targetDate,
      targetDayLabel: targetLabel,
      reduceMinutes: reduceMinutes,
      reason: '今天可用时间减少 ' + reduceMinutes + ' 分钟',
      items: items,
      warnings: warnings,
      errors: errors,
      beforeDailyMinutes: todayDay.totalMinutes,
      afterDailyMinutes: todayDay.totalMinutes - reduceMinutes,
      beforeTargetDailyMinutes: targetDay.totalMinutes,
      afterTargetDailyMinutes: targetDay.totalMinutes + reduceMinutes,
      dailyLimitMinutes: DAILY_LIMIT_MINUTES
    };
    previewSeq += 1;
    PREVIEWS.push(preview);
    return preview;
  }

  static async confirmAdjust(previewId: string): Promise<ActionResult> {
    let preview: PlanAdjustPreview | null = null;
    for (let i = 0; i < PREVIEWS.length; i++) {
      if (PREVIEWS[i].previewId === previewId) {
        preview = PREVIEWS[i];
      }
    }
    if (preview === null) {
      return { ok: false, message: '预览已失效，请重新预览' };
    }
    if (preview.planVersion !== planVersion) {
      return { ok: false, message: '计划版本已变化，请重新预览后再确认' };
    }
    if (preview.errors.length > 0) {
      return { ok: false, message: '存在冲突，不能确认调整' };
    }
    const task = findTask(preview.taskId);
    if (task === null) {
      return { ok: false, message: '任务不存在或已过期' };
    }
    if (task.timeRange !== preview.taskTimeRange || task.durationMinutes !== preview.taskDurationMinutes) {
      return { ok: false, message: '任务已被修改，请重新预览' };
    }
    const snapshot: PlanSnapshot = {
      snapshotId: 'snapshot_' + snapshotSeq,
      spaceId: preview.spaceId,
      spaceName: preview.spaceName,
      createdAt: '2026-10-18 10:30',
      reason: preview.reason,
      versionBefore: planVersion,
      versionAfter: planVersion + 1,
      originalTask: cloneTaskBefore(task),
      afterChecklist: [],
      createdTaskIds: [],
      afterTaskStatus: task.status
    };
    const todayStart = rangeStart(task.timeRange);
    const todayBudget = task.durationMinutes - preview.reduceMinutes;
    const todayChecklist: TaskChecklistItem[] = [];
    const movedChecklist: TaskChecklistItem[] = [];
    let usedMinutes = 0;
    for (let i = 0; i < task.checklist.length; i++) {
      const item = task.checklist[i];
      if (item.done) {
        todayChecklist.push({
          itemId: item.itemId,
          text: item.text,
          minutes: item.minutes,
          done: true
        });
        usedMinutes += item.minutes;
      }
    }
    let remainingToday = todayBudget - usedMinutes;
    let checkHandled = false;
    for (let i = 0; i < task.checklist.length; i++) {
      const item = task.checklist[i];
      if (!item.done && item.text.indexOf('提交前检查') >= 0 && remainingToday >= 5) {
        todayChecklist.push({
          itemId: task.taskId + '_today_check',
          text: '记录实验结果与检查（5分钟）',
          minutes: 5,
          done: false
        });
        remainingToday -= 5;
        movedChecklist.push({
          itemId: item.itemId,
          text: item.text,
          minutes: item.minutes - 5,
          done: false
        });
        checkHandled = true;
        break;
      }
    }
    for (let i = 0; i < task.checklist.length; i++) {
      const item = task.checklist[i];
      if (item.done) {
        continue;
      }
      if (checkHandled && item.text.indexOf('提交前检查') >= 0) {
        continue;
      }
      if (remainingToday > 0) {
        const take = Math.min(item.minutes, remainingToday);
        todayChecklist.push({
          itemId: item.itemId + '_today',
          text: take < item.minutes ? item.text + '（先做 ' + take + ' 分钟）' : item.text,
          minutes: take,
          done: false
        });
        remainingToday -= take;
        if (item.minutes - take > 0) {
          movedChecklist.push({
            itemId: item.itemId + '_moved',
            text: item.text,
            minutes: item.minutes - take,
            done: false
          });
        }
      } else {
        movedChecklist.push({
          itemId: item.itemId,
          text: item.text,
          minutes: item.minutes,
          done: false
        });
      }
    }
    task.durationMinutes = todayBudget;
    task.timeRange = minutesToClock(todayStart) + '-' + minutesToClock(todayStart + task.durationMinutes);
    task.checklist = todayChecklist;
    snapshot.afterChecklist = cloneChecklist(task.checklist);
    const targetStart = 19 * 60;
    const newTaskId = 'task_' + nextTaskSeq;
    nextTaskSeq += 1;
    const newTask: LearningTask = {
      taskId: newTaskId,
      spaceId: task.spaceId,
      spaceName: task.spaceName,
      title: task.title + '（续）',
      date: preview.targetDate,
      weekday: preview.targetDayLabel,
      timeRange: minutesToClock(targetStart) + '-' + minutesToClock(targetStart + preview.reduceMinutes),
      durationMinutes: preview.reduceMinutes,
      status: TaskStatus.NotStarted,
      output: '完成结果解释与提交检查',
      checklist: movedChecklist,
      nodeIds: task.nodeIds.slice(),
      nodeNames: task.nodeNames.slice()
    };
    PLAN_TASKS.push(newTask);
    snapshot.createdTaskIds.push(newTask.taskId);
    planVersion += 1;
    SNAPSHOTS.push(snapshot);
    removePreviewsForTask(preview.taskId);
    return {
      ok: true,
      message: '调整已确认：今天 ' + task.durationMinutes + ' 分钟 + ' +
        preview.targetDayLabel + ' ' + preview.reduceMinutes + ' 分钟，所有视图已同步'
    };
  }

  static async undoLastAdjust(spaceId: string): Promise<ActionResult> {
    const snapshot = activeSnapshotFor(spaceId);
    if (snapshot === null) {
      return { ok: false, message: '没有可撤销的调整' };
    }
    if (snapshot.versionAfter !== planVersion) {
      return { ok: false, message: '计划在此之后已有新的调整，无法撤销' };
    }
    const task = findTask(snapshot.originalTask.taskId);
    if (task === null) {
      return { ok: false, message: '原任务不存在，无法撤销' };
    }
    if (task.status !== snapshot.afterTaskStatus) {
      return { ok: false, message: '任务已有后续进展，撤销会丢失记录，请先确认' };
    }
    for (let i = 0; i < task.checklist.length; i++) {
      if (i >= snapshot.afterChecklist.length ||
        task.checklist[i].done !== snapshot.afterChecklist[i].done) {
        return { ok: false, message: '任务清单已有后续勾选，撤销会丢失进展' };
      }
    }
    for (let i = 0; i < snapshot.createdTaskIds.length; i++) {
      const created = findTask(snapshot.createdTaskIds[i]);
      if (created === null || created.status !== TaskStatus.NotStarted) {
        return { ok: false, message: '拆分出的任务已有进展，无法撤销' };
      }
      for (let j = 0; j < created.checklist.length; j++) {
        if (created.checklist[j].done) {
          return { ok: false, message: '拆分出的任务已有勾选，无法撤销' };
        }
      }
    }
    const undoErrors = validateSlot(task.date,
      rangeStart(snapshot.originalTask.timeRange),
      rangeEnd(snapshot.originalTask.timeRange),
      task.taskId,
      snapshot.originalTask.durationMinutes);
    if (undoErrors.length > 0) {
      return { ok: false, message: '撤销后会出现冲突：' + undoErrors[0] };
    }
    task.timeRange = snapshot.originalTask.timeRange;
    task.durationMinutes = snapshot.originalTask.durationMinutes;
    task.output = snapshot.originalTask.output;
    task.checklist = cloneChecklist(snapshot.originalTask.checklist);
    for (let i = PLAN_TASKS.length - 1; i >= 0; i--) {
      for (let j = 0; j < snapshot.createdTaskIds.length; j++) {
        if (PLAN_TASKS[i].taskId === snapshot.createdTaskIds[j]) {
          PLAN_TASKS.splice(i, 1);
        }
      }
    }
    const remaining: PlanSnapshot[] = [];
    for (let i = 0; i < SNAPSHOTS.length; i++) {
      if (SNAPSHOTS[i].snapshotId !== snapshot.snapshotId) {
        remaining.push(SNAPSHOTS[i]);
      }
    }
    SNAPSHOTS = remaining;
    planVersion += 1;
    return { ok: true, message: '已撤销调整，计划恢复为调整前版本' };
  }

  static async getActiveSnapshot(spaceId: string): Promise<PlanSnapshot | null> {
    return activeSnapshotFor(spaceId);
  }

  static async getReviewItems(): Promise<ReviewItem[]> {
    return REVIEW_ITEMS.slice();
  }

  static async getReviewCandidates(): Promise<ReviewCandidate[]> {
    return REVIEW_CANDIDATES.slice();
  }

  static async addReviewFromCandidate(candidateId: string): Promise<ActionResult> {
    const candidate = findCandidate(candidateId);
    if (candidate === null) {
      return { ok: false, message: '复习来源不存在' };
    }
    if (candidate.added) {
      return { ok: false, message: '这条记录已在复习清单中' };
    }
    candidate.added = true;
    REVIEW_ITEMS.push({
      reviewId: 'review_' + nextReviewSeq,
      spaceId: candidate.spaceId,
      spaceName: candidate.spaceName,
      nodeId: candidate.nodeId,
      nodeName: candidate.nodeName,
      recordId: candidate.recordId,
      kind: candidate.kind,
      title: candidate.title,
      note: candidate.note,
      addedAt: '2026-10-18 10:20',
      status: ReviewStatus.Pending,
      scheduledDate: '',
      scheduledTimeRange: '',
      taskId: ''
    });
    nextReviewSeq += 1;
    return { ok: true, message: '已加入复习清单；未排期前不会占用日历' };
  }

  static async completeReview(reviewId: string): Promise<ActionResult> {
    const review = findReview(reviewId);
    if (review === null) {
      return { ok: false, message: '复习项不存在或已过期' };
    }
    if (review.status === ReviewStatus.Done) {
      return { ok: false, message: '这条复习已完成' };
    }
    if (review.taskId !== '') {
      const task = findTask(review.taskId);
      if (task !== null) {
        task.status = TaskStatus.Done;
        for (let i = 0; i < task.checklist.length; i++) {
          task.checklist[i].done = true;
        }
      }
    }
    review.status = ReviewStatus.Done;
    return { ok: true, message: '本次复习已完成；立即复习不会自动占用日历' };
  }

  static async scheduleReview(reviewId: string, date: string, timeRange: string,
    durationMinutes: number): Promise<ActionResult> {
    const review = findReview(reviewId);
    if (review === null) {
      return { ok: false, message: '复习项不存在或已过期' };
    }
    if (review.status === ReviewStatus.Done) {
      return { ok: false, message: '这条复习已完成，无需再排期' };
    }
    if (review.status === ReviewStatus.Scheduled) {
      return { ok: false, message: '这条复习已经排期' };
    }
    if (weekdayOf(date) === '') {
      return { ok: false, message: '选择的时间不在本周计划范围内' };
    }
    const errors = validateSlot(date, rangeStart(timeRange), rangeEnd(timeRange), '', durationMinutes);
    if (errors.length > 0) {
      return { ok: false, message: errors[0] };
    }
    const taskId = 'task_' + nextTaskSeq;
    nextTaskSeq += 1;
    PLAN_TASKS.push({
      taskId: taskId,
      spaceId: review.spaceId,
      spaceName: review.spaceName,
      title: '复习：' + review.title,
      date: date,
      weekday: weekdayOf(date),
      timeRange: timeRange,
      durationMinutes: durationMinutes,
      status: TaskStatus.NotStarted,
      output: '完成一次主动复习并记录新的疑问',
      checklist: [
        { itemId: taskId + '_1', text: '回答这道复习题', minutes: 10, done: false },
        { itemId: taskId + '_2', text: '写下仍存在的疑问', minutes: 5, done: false }
      ],
      nodeIds: [review.nodeId],
      nodeNames: [review.nodeName]
    });
    review.status = ReviewStatus.Scheduled;
    review.scheduledDate = date;
    review.scheduledTimeRange = timeRange;
    review.taskId = taskId;
    return {
      ok: true,
      message: '已排期到 ' + formatDateLabel(date) + ' ' + timeRange + '，现在才生成有时间的任务'
    };
  }

  static async getProjectLinks(spaceId: string): Promise<ProjectLink[]> {
    if (spaceId === '') {
      return PROJECT_LINKS;
    }
    const result: ProjectLink[] = [];
    for (let i = 0; i < PROJECT_LINKS.length; i++) {
      if (PROJECT_LINKS[i].spaceId === spaceId) {
        result.push(PROJECT_LINKS[i]);
      }
    }
    return result;
  }
}
