// PracticeService.ets
// FlowSpace · 陈珂睿模块统一服务层（内存版 Mock，后续可整体替换为后端实现）
// 所有页面只通过本服务读写练习/对比记录与复习项，保证数据源唯一、避免各页各自维护副本。

import {
  CompareRecord,
  NodeRef,
  PracticeRecord,
  ReviewItem,
  STATE_ACTUAL,
  STATE_FEEDBACK,
  STATE_SOURCE,
  getNodeRef
} from '../model/PracticeModels';

function nowText(): string {
  const d: Date = new Date();
  const mm: number = d.getMonth() + 1;
  const dd: number = d.getDate();
  const hh: number = d.getHours();
  const min: number = d.getMinutes();
  const pad = (n: number): string => (n < 10 ? '0' + n : '' + n);
  return mm + '-' + dd + ' ' + pad(hh) + ':' + pad(min);
}

let recordSeq: number = 1000;

function nextRecordId(prefix: string): string {
  recordSeq = recordSeq + 1;
  return prefix + '_' + recordSeq.toString();
}

// ── 内存数据（模块唯一副本）──
let practiceRecords: PracticeRecord[] = [
  {
    recordId: 'rec_seed_1',
    spaceId: 'space_hm',
    nodeId: 'state',
    nodeName: getNodeRef('state').name,
    spaceName: getNodeRef('state').spaceName,
    templateId: 'tpl_state',
    question: '使用状态变量时，点击按钮后，数字会更新吗？',
    predicted: '不会更新',
    actual: STATE_ACTUAL,
    correct: false,
    explanation: '状态变化会触发相关界面更新。',
    feedback: STATE_FEEDBACK,
    source: STATE_SOURCE,
    addToReview: false,
    createdAt: '10-17 21:10'
  }
];

let compareRecords: CompareRecord[] = [
  {
    recordId: 'cmp_seed_1',
    spaceId: 'space_ds',
    spaceName: getNodeRef('stack').spaceName,
    nodeIdA: 'stack',
    nodeIdB: 'queue',
    nodeNameA: getNodeRef('stack').name,
    nodeNameB: getNodeRef('queue').name,
    templateId: 'tpl_stack_queue',
    inputSeq: ['A', 'B', 'C'],
    stackOut: 'C',
    queueOut: 'A',
    stackRemain: ['B', 'A'],
    queueRemain: ['B', 'C'],
    diffText: '栈取最后加入的，队列取最先加入的。',
    explanation: '栈从同一端进出，队列从两端进出，所以顺序不同。',
    addToReview: false,
    createdAt: '10-17 19:40'
  }
];

let reviewItems: ReviewItem[] = [];

// draftId → recordId：保证重复提交（相同 draftId）不会写入两条记录
const draftIndex: Map<string, string> = new Map<string, string>();

export class PracticeService {
  // ── 节点引用（供页面展示“回到 空间 / 节点”）──
  static getNodeRef(nodeId: string): NodeRef {
    return getNodeRef(nodeId);
  }

  // ── 练习记录 ──
  static async getPracticeRecords(spaceId?: string, nodeId?: string): Promise<PracticeRecord[]> {
    return practiceRecords.filter((r: PracticeRecord) => {
      if (spaceId !== undefined && spaceId !== '' && r.spaceId !== spaceId) {
        return false;
      }
      if (nodeId !== undefined && nodeId !== '' && r.nodeId !== nodeId) {
        return false;
      }
      return true;
    });
  }

  // 幂等保存：相同 draftId 重复提交时更新同一条，不新增
  static async savePracticeRecord(draftId: string, record: PracticeRecord): Promise<PracticeRecord> {
    const existingId: string | undefined = draftIndex.get(draftId);
    if (existingId !== undefined) {
      const idx: number = practiceRecords.findIndex((r: PracticeRecord) => r.recordId === existingId);
      if (idx >= 0) {
        record.recordId = existingId;
        practiceRecords[idx] = record;
      }
    } else {
      if (record.recordId === '' || record.recordId === undefined) {
        record.recordId = nextRecordId('rec');
      }
      record.createdAt = nowText();
      practiceRecords.push(record);
      draftIndex.set(draftId, record.recordId);
    }
    PracticeService.syncReview(record.addToReview, record.nodeId, record.recordId, 'practice');
    return record;
  }

  // ── 对比记录（关联两个节点，但只计一条）──
  static async getCompareRecords(spaceId?: string, nodeId?: string): Promise<CompareRecord[]> {
    return compareRecords.filter((r: CompareRecord) => {
      if (spaceId !== undefined && spaceId !== '' && r.spaceId !== spaceId) {
        return false;
      }
      if (nodeId !== undefined && nodeId !== '' && r.nodeIdA !== nodeId && r.nodeIdB !== nodeId) {
        return false;
      }
      return true;
    });
  }

  static async saveCompareRecord(draftId: string, record: CompareRecord): Promise<CompareRecord> {
    const existingId: string | undefined = draftIndex.get(draftId);
    if (existingId !== undefined) {
      const idx: number = compareRecords.findIndex((r: CompareRecord) => r.recordId === existingId);
      if (idx >= 0) {
        record.recordId = existingId;
        compareRecords[idx] = record;
      }
    } else {
      if (record.recordId === '' || record.recordId === undefined) {
        record.recordId = nextRecordId('cmp');
      }
      record.createdAt = nowText();
      compareRecords.push(record);
      draftIndex.set(draftId, record.recordId);
    }
    PracticeService.syncReview(record.addToReview, record.nodeIdA, record.recordId, 'compare');
    return record;
  }

  // ── 复习项（陈珂睿 → 黄崇杰 handoff：nodeId + recordId）──
  static async getReviewItems(): Promise<ReviewItem[]> {
    return reviewItems;
  }

  // 加入复习：仅登记“需要复习”，不自动生成排期任务（由黄崇杰模块消费）
  private static syncReview(add: boolean, nodeId: string, recordId: string, kind: 'practice' | 'compare'): void {
    const idx: number = reviewItems.findIndex((it: ReviewItem) =>
      it.nodeId === nodeId && it.recordId === recordId && it.kind === kind);
    if (add) {
      if (idx < 0) {
        reviewItems.push({ nodeId: nodeId, recordId: recordId, kind: kind, createdAt: nowText() });
      }
    } else {
      if (idx >= 0) {
        reviewItems.splice(idx, 1);
      }
    }
  }
}
