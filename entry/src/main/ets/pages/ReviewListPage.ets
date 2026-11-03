import { EmptyState } from '../components/EmptyState';
import { SectionTitle } from '../components/SectionTitle';
import { StatusTag } from '../components/StatusTag';
import {
  ActionResult,
  ReviewCandidate,
  ReviewItem,
  ReviewStatus,
  formatDateLabel,
  reviewStatusKind,
  reviewStatusText
} from '../model/Models';
import { MockService } from '../service/MockService';

interface ReviewSlot {
  slotId: string;
  label: string;
  date: string;
  timeRange: string;
  durationMinutes: number;
}

const REVIEW_SLOTS: ReviewSlot[] = [
  { slotId: 'slot_1', label: '今天 21:30-21:45', date: '2026-10-18', timeRange: '21:30-21:45', durationMinutes: 15 },
  { slotId: 'slot_2', label: '明天 19:00-19:15', date: '2026-10-19', timeRange: '19:00-19:15', durationMinutes: 15 },
  { slotId: 'slot_3', label: '周四 21:00-21:15', date: '2026-10-22', timeRange: '21:00-21:15', durationMinutes: 15 },
  { slotId: 'slot_4', label: '周五 19:00-19:15', date: '2026-10-23', timeRange: '19:00-19:15', durationMinutes: 15 }
];

@Component
export struct ReviewListPage {
  pathStack: NavPathStack = new NavPathStack();
  @State items: ReviewItem[] = [];
  @State candidates: ReviewCandidate[] = [];
  @State loaded: boolean = false;
  @State showAdd: boolean = false;
  @State activeReview: ReviewItem | null = null;
  @State reviewDraft: string = '';
  @State scheduleReviewId: string = '';
  @State selectedSlotIndex: number = -1;
  @State scheduleError: string = '';
  private shownOnce: boolean = false;

  private load(): void {
    MockService.getReviewItems().then((list: ReviewItem[]) => {
      this.items = list;
    });
    MockService.getReviewCandidates().then((list: ReviewCandidate[]) => {
      this.candidates = list;
      this.loaded = true;
    });
  }

  private pendingItems(): ReviewItem[] {
    const result: ReviewItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].status === ReviewStatus.Pending) {
        result.push(this.items[i]);
      }
    }
    return result;
  }

  private scheduledItems(): ReviewItem[] {
    const result: ReviewItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].status === ReviewStatus.Scheduled) {
        result.push(this.items[i]);
      }
    }
    return result;
  }

  private doneItems(): ReviewItem[] {
    const result: ReviewItem[] = [];
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].status === ReviewStatus.Done) {
        result.push(this.items[i]);
      }
    }
    return result;
  }

  private availableCandidates(): ReviewCandidate[] {
    const result: ReviewCandidate[] = [];
    for (let i = 0; i < this.candidates.length; i++) {
      if (!this.candidates[i].added) {
        result.push(this.candidates[i]);
      }
    }
    return result;
  }

  private toggleAdd(): void {
    this.showAdd = !this.showAdd;
    this.activeReview = null;
    this.scheduleReviewId = '';
    this.scheduleError = '';
  }

  private openReview(item: ReviewItem): void {
    this.activeReview = item;
    this.reviewDraft = '';
    this.showAdd = false;
    this.scheduleReviewId = '';
  }

  private submitReview(): void {
    if (this.activeReview === null) {
      return;
    }
    MockService.completeReview(this.activeReview.reviewId).then((result: ActionResult) => {
      this.getUIContext().getPromptAction().showToast({ message: result.message });
      this.activeReview = null;
      this.reviewDraft = '';
      this.load();
    });
  }

  private openSchedule(item: ReviewItem): void {
    this.scheduleReviewId = item.reviewId;
    this.selectedSlotIndex = -1;
    this.scheduleError = '';
    this.showAdd = false;
    this.activeReview = null;
  }

  private confirmSchedule(): void {
    if (this.selectedSlotIndex < 0 || this.selectedSlotIndex >= REVIEW_SLOTS.length) {
      this.scheduleError = '请先选择一个时间';
      return;
    }
    if (this.scheduleReviewId === '') {
      return;
    }
    const slot = REVIEW_SLOTS[this.selectedSlotIndex];
    MockService.scheduleReview(this.scheduleReviewId, slot.date, slot.timeRange, slot.durationMinutes)
      .then((result: ActionResult) => {
        if (result.ok) {
          this.getUIContext().getPromptAction().showToast({ message: result.message });
          this.scheduleReviewId = '';
          this.selectedSlotIndex = -1;
          this.scheduleError = '';
          this.load();
        } else {
          this.scheduleError = result.message;
        }
      });
  }

  private addCandidate(candidateId: string): void {
    MockService.addReviewFromCandidate(candidateId).then((result: ActionResult) => {
      this.getUIContext().getPromptAction().showToast({ message: result.message });
      if (result.ok) {
        this.load();
      }
    });
  }

  private openTask(item: ReviewItem): void {
    if (item.taskId !== '') {
      this.pathStack.pushPathByName('taskDetail', item.taskId);
    }
  }

  @Builder
  headerCard() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text('复习清单')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('主动加入的疑问与练习，由你决定什么时候复习')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.showAdd ? '收起' : '＋ 主动加入')
          .fontSize(12)
          .fontColor($r('app.color.brand'))
          .backgroundColor($r('app.color.brand_weak'))
          .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .borderRadius(999)
          .onClick(() => {
            this.toggleAdd();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 16 }) {
        Text('待复习 ' + this.pendingItems().length)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
        Text('已排期 ' + this.scheduledItems().length)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
        Text('已复习 ' + this.doneItems().length)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')

      Text('加入清单不等于自动排期；只有确认时间后才会生成有时间的任务。')
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))
        .backgroundColor($r('app.color.bg_card'))
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .borderRadius(8)
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  addPanel() {
    Column({ space: 10 }) {
      Text('从练习记录主动加入')
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('来源记录保留 nodeId 与 recordId，便于回到原知识点。')
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))

      if (this.availableCandidates().length === 0) {
        Text('暂无可加入的练习记录')
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
      } else {
        ForEach(this.availableCandidates(), (candidate: ReviewCandidate) => {
          Column({ space: 6 }) {
            Row({ space: 8 }) {
              StatusTag({ label: candidate.kind, kind: candidate.kind === '疑问' ? 'orange' : 'blue' })
              Text(candidate.title)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Text(candidate.nodeName + ' · 记录 ' + candidate.recordId)
              .fontSize(10)
              .fontColor($r('app.color.text_tertiary'))
            Text(candidate.note)
              .fontSize(10)
              .fontColor($r('app.color.text_secondary'))

            Button('加入清单')
              .fontSize(11)
              .fontColor($r('app.color.brand'))
              .backgroundColor($r('app.color.brand_weak'))
              .height(28)
              .borderRadius(8)
              .onClick(() => {
                this.addCandidate(candidate.candidateId);
              })
          }
          .width('100%')
          .padding(10)
          .borderRadius(10)
          .backgroundColor($r('app.color.bg_page'))
          .alignItems(HorizontalAlign.Start)
        }, (candidate: ReviewCandidate) => candidate.candidateId)
      }
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('app.color.brand_weak'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  reviewPanel() {
    Column({ space: 8 }) {
      Row() {
        Text('立即复习')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('取消')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.activeReview = null;
            this.reviewDraft = '';
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.activeReview!.title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
      Text('回顾：' + this.activeReview!.note)
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))

      TextArea({ placeholder: '写下你的解释，用于自我检查', text: this.reviewDraft })
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .backgroundColor($r('app.color.bg_page'))
        .borderRadius(10)
        .height(78)
        .width('100%')
        .onChange((value: string) => {
          this.reviewDraft = value;
        })

      Button('提交自我检查')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.on_brand'))
        .backgroundColor($r('app.color.brand'))
        .height(36)
        .width('100%')
        .borderRadius(9)
        .enabled(this.reviewDraft.trim() !== '')
        .onClick(() => {
          this.submitReview();
        })
      Text('立即复习只记录完成，不会自动写入日历。')
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('app.color.brand_weak'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  schedulePanel() {
    Column({ space: 9 }) {
      Row() {
        Text('安排复习时间')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text('取消')
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            this.scheduleReviewId = '';
            this.selectedSlotIndex = -1;
            this.scheduleError = '';
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text('选择一个空档；确认后才会生成有时间的任务。')
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))

      ForEach(REVIEW_SLOTS, (slot: ReviewSlot, index: number) => {
        Row({ space: 8 }) {
          Text(slot.label)
            .fontSize(12)
            .fontColor(this.selectedSlotIndex === index ?
              $r('app.color.on_brand') : $r('app.color.text_primary'))
            .layoutWeight(1)
          Text(this.selectedSlotIndex === index ? '已选择' : '选择')
            .fontSize(10)
            .fontColor(this.selectedSlotIndex === index ?
              $r('app.color.on_brand') : $r('app.color.brand'))
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .borderRadius(9)
        .backgroundColor(this.selectedSlotIndex === index ?
          $r('app.color.brand') : $r('app.color.bg_page'))
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.selectedSlotIndex = index;
          this.scheduleError = '';
        })
      }, (slot: ReviewSlot) => slot.slotId)

      if (this.scheduleError !== '') {
        Text(this.scheduleError)
          .fontSize(10)
          .fontColor($r('app.color.tag_orange_text'))
          .backgroundColor($r('app.color.tag_orange_bg'))
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
          .borderRadius(8)
          .width('100%')
      }

      Button('确认安排')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.on_brand'))
        .backgroundColor($r('app.color.brand'))
        .height(36)
        .width('100%')
        .borderRadius(9)
        .enabled(this.selectedSlotIndex >= 0)
        .onClick(() => {
          this.confirmSchedule();
        })
    }
    .width('100%')
    .padding(14)
    .borderRadius(14)
    .backgroundColor($r('app.color.brand_weak'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  reviewCard(item: ReviewItem) {
    Column({ space: 7 }) {
      Row({ space: 8 }) {
        StatusTag({ label: item.kind, kind: item.kind === '疑问' ? 'orange' : 'blue' })
        Text(item.title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
        StatusTag({ label: reviewStatusText(item.status), kind: reviewStatusKind(item.status) })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(item.nodeName + ' · ' + item.spaceName)
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))
      Text(item.note)
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
      if (item.status === ReviewStatus.Scheduled) {
        Text('已排期：' + formatDateLabel(item.scheduledDate) + ' ' + item.scheduledTimeRange)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand'))
      } else {
        Text('加入于 ' + item.addedAt + ' · 来源记录 ' + item.recordId)
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
      }

      Row({ space: 8 }) {
        if (item.status === ReviewStatus.Pending) {
          Button('立即复习')
            .fontSize(11)
            .fontColor($r('app.color.on_brand'))
            .backgroundColor($r('app.color.brand'))
            .height(30)
            .borderRadius(8)
            .onClick(() => {
              this.openReview(item);
            })
          Button('安排时间')
            .fontSize(11)
            .fontColor($r('app.color.brand'))
            .backgroundColor($r('app.color.brand_weak'))
            .height(30)
            .borderRadius(8)
            .onClick(() => {
              this.openSchedule(item);
            })
        } else if (item.status === ReviewStatus.Scheduled) {
          Button('开始复习')
            .fontSize(11)
            .fontColor($r('app.color.on_brand'))
            .backgroundColor($r('app.color.brand'))
            .height(30)
            .borderRadius(8)
            .onClick(() => {
              this.openReview(item);
            })
          Button('查看任务')
            .fontSize(11)
            .fontColor($r('app.color.brand'))
            .backgroundColor($r('app.color.brand_weak'))
            .height(30)
            .borderRadius(8)
            .onClick(() => {
              this.openTask(item);
            })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor($r('app.color.bg_card'))
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    NavDestination() {
      if (!this.loaded) {
        Column() {
          Text('加载中...')
            .fontSize(12)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 12 }) {
            this.headerCard()
            if (this.showAdd) {
              this.addPanel()
            }
            if (this.activeReview !== null) {
              this.reviewPanel()
            }
            if (this.scheduleReviewId !== '') {
              this.schedulePanel()
            }

            SectionTitle({ title: '待复习（未排期）' })
            if (this.pendingItems().length === 0) {
              Text('没有未排期的复习项')
                .fontSize(11)
                .fontColor($r('app.color.text_tertiary'))
            } else {
              ForEach(this.pendingItems(), (item: ReviewItem) => {
                this.reviewCard(item)
              }, (item: ReviewItem) => item.reviewId)
            }

            SectionTitle({ title: '已排期' })
            if (this.scheduledItems().length === 0) {
              Text('还没有安排时间的复习')
                .fontSize(11)
                .fontColor($r('app.color.text_tertiary'))
            } else {
              ForEach(this.scheduledItems(), (item: ReviewItem) => {
                this.reviewCard(item)
              }, (item: ReviewItem) => item.reviewId)
            }

            if (this.doneItems().length > 0) {
              SectionTitle({ title: '已完成' })
              ForEach(this.doneItems(), (item: ReviewItem) => {
                this.reviewCard(item)
              }, (item: ReviewItem) => item.reviewId)
            }

            if (this.items.length === 0) {
              EmptyState({
                title: '复习清单是空的',
                hint: '从练习记录中主动加入想再看的疑问或练习',
                actionText: '主动加入',
                onAction: () => {
                  this.showAdd = true;
                }
              })
            }
          }
          .padding({ left: 16, right: 16, top: 14, bottom: 24 })
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')
        .align(Alignment.TopStart)
      }
    }
    .title('复习清单')
    .backgroundColor($r('app.color.bg_page'))
    .onReady((ctx: NavDestinationContext) => {
      this.pathStack = ctx.pathStack;
      this.load();
    })
    .onShown(() => {
      if (this.shownOnce) {
        this.load();
      } else {
        this.shownOnce = true;
      }
    })
  }
}

@Builder
export function reviewListBuilder() {
  ReviewListPage()
}
