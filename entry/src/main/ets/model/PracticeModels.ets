// PracticeModels.ets
// FlowSpace · 陈珂睿模块统一数据模型（行动工作台 / 概念对比 / 练习反馈 / 学习记录）
// 说明：本文件是陈珂睿模块的唯一数据来源，所有页面（15/09/10/16/18）均从这里读取与写入，
// 满足分工文档“前端页面不各自维护独立数据副本”的约束。

// 页面启动参数（白长林 → 陈珂睿 handoff：spaceId / nodeId / templateId / 可选 taskId）
export interface LaunchParams {
  spaceId: string;
  nodeId: string;
  templateId?: string;
  taskId?: string;
}

// 15 → 16 传递的参数（携带用户在行动工作台的作答与解释）
export interface PracticeLaunchParams extends LaunchParams {
  draftId: string;        // 幂等草稿号，重复提交不重复写入
  predicted: string;      // 用户的预测：'会更新' / '不会更新'
  explanation: string;    // 用户在 15 写的解释/问题
  situation: string;      // '能解释了' / '还没懂' / '先留个问题'
}

// 09 → 10 传递的参数（携带对比输入与预测）
export interface CompareLaunchParams extends LaunchParams {
  draftId: string;
  inputSeq: string[];     // 已加入的元素序列
  stackPick: string;      // 用户对栈的预测取出：'A'/'B'/'C'
  queuePick: string;      // 用户对队列的预测取出
}

// 节点引用信息（用于“记录将回到：空间 / 节点”等展示，以及记录按节点回流）
export interface NodeRef {
  nodeId: string;
  name: string;
  spaceId: string;
  spaceName: string;
}

// 练习记录（15 → 16 保存后写入；18 可回看）
export interface PracticeRecord {
  recordId: string;
  spaceId: string;
  nodeId: string;
  nodeName: string;
  spaceName: string;
  templateId: string;
  question: string;       // 被问的问题
  predicted: string;      // 用户预测，如 '不会更新' / '会更新'
  actual: string;         // 实际结果，如 '会更新'
  correct: boolean;       // 预测是否正确
  explanation: string;    // 个人解释（用户填写）
  feedback: string;       // 规则校验反馈（统一模板给出）
  source: string;         // 来源（资料名）
  addToReview: boolean;   // 是否加入复习
  createdAt: string;      // 创建时间
}

// 对比实验记录（09 → 10 保存后写入；关联两个节点但只计一条记录）
export interface CompareRecord {
  recordId: string;
  spaceId: string;
  spaceName: string;      // 所属空间名（记录展示“回到：空间/节点”用）
  nodeIdA: string;        // 关联节点 A（如 栈）
  nodeIdB: string;        // 关联节点 B（如 队列）
  nodeNameA: string;
  nodeNameB: string;
  templateId: string;
  inputSeq: string[];     // 输入序列，如 ['A','B','C']
  stackOut: string;       // 栈首次取出，如 'C'
  queueOut: string;       // 队列首次取出，如 'A'
  stackRemain: string[];  // 栈剩余，如 ['B','A']
  queueRemain: string[];  // 队列剩余，如 ['B','C']
  diffText: string;       // 差异说明
  explanation: string;    // 个人解释
  addToReview: boolean;
  createdAt: string;
}

// 复习项（陈珂睿 → 黄崇杰 handoff：nodeId + recordId；加入不等于自动排期）
export interface ReviewItem {
  nodeId: string;
  recordId: string;
  kind: 'practice' | 'compare';
  createdAt: string;
}

// 模板类型
export const TEMPLATE_STATE: string = 'tpl_state';        // 状态变量练习（15/16）
export const TEMPLATE_STACK_QUEUE: string = 'tpl_stack_queue'; // 栈/队列对比（09/10）

// 节点引用表：覆盖本模块用到的演示节点。新增节点时在此登记即可。
const NODE_REFS: NodeRef[] = [
  { nodeId: 'hm', name: '鸿蒙入门', spaceId: 'space_hm', spaceName: '鸿蒙课程项目' },
  { nodeId: 'arkts', name: 'ArkTS 基础', spaceId: 'space_hm', spaceName: '鸿蒙课程项目' },
  { nodeId: 'arkui', name: 'ArkUI 布局', spaceId: 'space_hm', spaceName: '鸿蒙课程项目' },
  { nodeId: 'state', name: '状态管理', spaceId: 'space_hm', spaceName: '鸿蒙课程项目' },
  { nodeId: 'nav', name: '页面导航', spaceId: 'space_hm', spaceName: '鸿蒙课程项目' },
  { nodeId: 'save', name: '数据保存', spaceId: 'space_hm', spaceName: '鸿蒙课程项目' },
  { nodeId: 'stack', name: '栈', spaceId: 'space_ds', spaceName: '数据结构与算法' },
  { nodeId: 'queue', name: '队列', spaceId: 'space_ds', spaceName: '数据结构与算法' }
];

export function getNodeRef(nodeId: string): NodeRef {
  for (let i = 0; i < NODE_REFS.length; i++) {
    if (NODE_REFS[i].nodeId === nodeId) {
      return NODE_REFS[i];
    }
  }
  // 未知节点：返回占位，避免界面崩溃
  return { nodeId: nodeId, name: nodeId, spaceId: 'space_hm', spaceName: '鸿蒙课程项目' };
}

// 状态变量的标准题目（样例模板，固定文案，非真实 AI 生成）
export const STATE_QUESTION: string = '使用状态变量时，点击按钮后，数字会更新吗？';
export const STATE_ACTUAL: string = '会更新';
export const STATE_FEEDBACK: string =
  '会更新。这个示例使用了状态变量（@State），变量一变，用到它的界面会自动重画。';
export const STATE_SOURCE: string = '状态变量示例 · 样例材料';
