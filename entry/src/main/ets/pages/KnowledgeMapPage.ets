// KnowledgeMap.ets
// FlowSpace · 知识地图页面（鸿蒙 ArkTS / ArkUI 版）
// 功能：05 地图/列表(关系用文字展示) · 06 节点详情(资料/样例/笔记/练习/关联任务/相关节点 + 任务与理解状态独立) · 07 材料详情 · 03/04 新建空间 · 08 空间内搜索

// ── 1. 数据模型：和 HTML 里的 NODES 是同一份，只是用 interface 描述形状 ──
interface KnowNode {
  id: string
  name: string
  type: string
  status: string      // 任务状态：done=已掌握  doing=进行中  todo=未学
  understood: string  // 理解状态：yes=已理解  no=未理解（和任务状态分开记）
  x: number           // 地图横纵坐标（百分比 0~100）
  y: number
  desc: string
  res: string         // 原始资料（材料标题）
  matBody: string     // 材料正文（07 材料详情页用）
  matFrom: string     // 材料来源（07 材料详情页用）
  example: string
  note: string
  practice: string
  tasks: string[]     // 关联任务（06 要求分开展示）
}

// ── 2. 状态翻译成中文（用函数，避开“对象没户口”的报错）──
function statusText(s: string): string {
  if (s === 'done') { return '已掌握' }
  if (s === 'doing') { return '进行中' }
  return '未学'
}

// ── 3. 节点之间的关系（05 要求“节点与关系清晰”）：from → to ──
interface KnowEdge {
  from: string
  to: string
  label: string
}

const EDGES: KnowEdge[] = [
  { from: 'hm',    to: 'arkts', label: '前置' },
  { from: 'hm',    to: 'arkui', label: '前置' },
  { from: 'arkts', to: 'arkui', label: '前置' },
  { from: 'arkui', to: 'state', label: '前置' },
  { from: 'state', to: 'nav',   label: '前置' },
  { from: 'state', to: 'save',  label: '前置' },
  { from: 'nav',   to: 'todo',  label: '用于实现' },
  { from: 'save',  to: 'todo',  label: '用于实现' },
  { from: 'arkui', to: 'card',  label: '用于实现' },
  { from: 'card',  to: 'todo',  label: '用于实现' },
]

// ── 4. 同一份节点数据（HTML 里 NODES 数组原样搬过来）──
const NODES: KnowNode[] = [
  { id: 'hm',    name: '鸿蒙入门',     type: '目标', status: 'done',  understood: 'yes', x: 50, y: 12, desc: '本次学习目标', res: '《鸿蒙生态概述》课件第1章', matBody: '本章介绍鸿蒙系统的定位、分布式能力和开发生态，帮你建立整体认识：一次开发多端部署是什么意思，以及和安卓的区别。', matFrom: '《鸿蒙生态概述》课件第1章（课程官网下载）', example: '7天做出课程待办原型', note: '从想学什么出发', practice: '写下最想弄懂的概念', tasks: ['完成第1章预习', '写下三个想弄懂的问题'] },
  { id: 'arkts', name: 'ArkTS 基础',   type: '概念', status: 'done',  understood: 'yes', x: 28, y: 42, desc: '主力开发语言', res: 'ArkTS 语言指南', matBody: 'ArkTS 是鸿蒙的主力开发语言，在 TypeScript 基础上收紧了类型规则：变量要先说类型、对象要有明确形状。写完的代码更稳，但比 JS 严。', matFrom: '华为开发者联盟 · ArkTS 语言指南', example: 'let count: number = 0;', note: '和 TS 很像', practice: '写带类型的变量', tasks: ['完成类型声明练习 5 题', '把一段 JS 改写成 ArkTS'] },
  { id: 'arkui', name: 'ArkUI 布局',   type: '概念', status: 'doing', understood: 'yes', x: 50, y: 46, desc: '声明式 UI', res: 'ArkUI 官方布局文档', matBody: 'ArkUI 是声明式 UI 框架：你描述界面“长什么样”，框架负责画和更新。常用容器是 Column（竖排）、Row（横排）、Stack（叠放），间距用 padding 和 margin 控制。', matFrom: 'ArkUI 官方布局文档', example: 'Column(){ Text("你好") }', note: '先想结构', practice: '搭课程卡片', tasks: ['用 Column/Row 搭出课程卡片', '说清 padding 和 margin 的区别'] },
  { id: 'state', name: '状态管理',     type: '概念', status: 'doing', understood: 'no',  x: 30, y: 74, desc: '数据驱动界面', res: '状态管理文档', matBody: '状态管理是声明式 UI 的心脏：给变量加 @State，它一变，用到它的界面自动重画。你不再手动“刷新界面”，只管改数据。', matFrom: 'ArkUI 状态管理官方文档', example: '@State count=0', note: '普通变量不行', practice: '按钮让数字+1', tasks: ['做一个点击 +1 的计数器', '解释 @State 为什么能驱动界面'] },
  { id: 'nav',   name: '页面导航',     type: '概念', status: 'todo',  understood: 'no',  x: 70, y: 70, desc: '多页面跳转', res: 'Router 文档', matBody: '页面导航负责多页面跳转：用 Router pushUrl 推到新页面，可以带参数（比如节点 id），详情页再根据参数显示对应内容。', matFrom: 'Router 导航开发指南', example: 'pushUrl 带 nodeId', note: 'nodeId 串联', practice: '点节点跳详情', tasks: ['实现点节点跳详情并带上 id', '画一张页面跳转流程图'] },
  { id: 'save',  name: '数据保存',     type: '概念', status: 'todo',  understood: 'no',  x: 48, y: 80, desc: '本地存储', res: 'Preferences 文档', matBody: 'Preferences 提供轻量本地存储，适合存待办、设置这类小数据。存进去重启应用还在，是单机版应用最常用的存法。', matFrom: 'Preferences 数据存储文档', example: '存上次停在哪', note: '单机用本地', practice: '保存待办重启读', tasks: ['用 Preferences 存一次待办', '重启应用验证数据还在'] },
  { id: 'card',  name: '服务卡片',     type: '功能', status: 'todo',  understood: 'no',  x: 74, y: 44, desc: '桌面卡片', res: '服务卡片指南', matBody: '服务卡片让应用内容直达桌面：不用打开应用就能看到进度，点一下还能跳进应用。支持定时刷新和点击跳转。', matFrom: '服务卡片开发指南', example: '显示继续学习', note: '只展示入口', practice: '做进度卡片', tasks: ['设计一个学习进度服务卡片', '测试卡片点击跳转应用'] },
  { id: 'todo',  name: '课程待办原型', type: '功能', status: 'todo',  understood: 'no',  x: 50, y: 94, desc: '真实成果', res: '课程待办需求', matBody: '课程待办原型综合运用前面所有知识：添加待办、勾选完成、更新进度，并用本地存储保存。这是本课程的最终考核作品。', matFrom: '课程实践项目需求说明', example: '添加→勾选→更新', note: '用武之地', practice: '可勾选待办列表', tasks: ['整合待办的增删改查', '准备演示：添加→勾选→更新'] },
]

// ── 5. 主页面：地图/列表(05) + 详情(06) + 材料(07) + 新建空间(03/04) + 搜索(08) 全在这一个页面里 ──
@Entry
@Component
struct KnowledgeMap {
  // 地图/列表/详情 用的状态
  @State nodes: KnowNode[] = NODES
  @State view: string = 'map'          // map / list
  // selected 一变（点了别的节点），就把那个节点的理解状态同步到 selectedUnderstood
  @State @Watch('syncUnderstood') selected: KnowNode | null = null
  @State selectedUnderstood: string = 'no'

  // 笔记编辑用的状态
  @State noteEditing: boolean = false
  @State noteDraft: string = ''

  // 材料详情页（07）
  @State showMaterial: boolean = false

  // 空间内搜索（08）
  @State showSearch: boolean = false
  @State searchKeyword: string = ''
  @State searchTab: string = 'all'     // all=全部 know=知识 note=笔记 practice=练习

  // 新建空间页（03/04）用的状态（草稿就在本页面里，关掉再开也不丢）
  @State showCreate: boolean = false   // true=显示新建空间页
  @State createMode: string = 'form'   // form=填表单  preview=预览确认
  @State createError: string = ''      // 校验不通过时的提示
  @State goalDraft: string = ''        // 三个草稿：目标 / 材料 / 时间
  @State materialDraft: string = ''
  @State timeDraft: string = ''

  build() {
    Column() {
      // 顶部：地图 / 列表 / 新建 / 搜索
      Row() {
        Button('地图').fontSize(14).margin(4).onClick(() => { this.view = 'map' })
        Button('列表').fontSize(14).margin(4).onClick(() => { this.view = 'list' })
        Button('＋ 新建').fontSize(14).margin(4).onClick(() => { this.showCreate = true })
        Button('搜索').fontSize(14).margin(4).onClick(() => { this.showSearch = true })
      }

      // 内容区：用 Stack 叠放“地图/列表”“详情面板”“材料页”“搜索页”“新建空间页”
      Stack() {
        if (this.view === 'map') {
          // 地图：Stack + 绝对定位节点（对应 HTML 的 drawMap）
          // 每个节点下方用小字标出它的“后续节点”，关系一眼可见
          ForEach(this.nodes, (n: KnowNode) => {
            Column() {
              Text(n.name).fontSize(14).fontWeight(FontWeight.Medium)
              Text(n.type).fontSize(11).fontColor('#4f6bed')
              Text(this.mapRelText(n)).fontSize(9).fontColor('#9aa3b2').margin({ top: 2 })
            }
            .position({ x: n.x + '%', y: n.y + '%' })
            .translate({ x: '-50%', y: '-50%' })
            .padding(10)
            .border({ width: 1, color: '#d8dee9' })
            .borderRadius(12)
            .backgroundColor('#ffffff')
            .onClick(() => { this.selected = n })
          }, (n: KnowNode) => n.id)
        } else {
          // 列表：对应 HTML 的 renderList
          List({ space: 12 }) {
            ForEach(this.nodes, (n: KnowNode) => {
              ListItem() {
                Row() {
                  Text(n.name).fontSize(15).fontWeight(FontWeight.Medium)
                  Text(`${n.type} · ${statusText(n.status)}`).fontSize(12).fontColor('#6b7280').margin({ left: 16 })
                }
                .justifyContent(FlexAlign.Center)
                .width('100%')
                .padding(12)
                .backgroundColor('#ffffff')
                .border({ width: 1, color: '#d8dee9' })
                .borderRadius(12)
                .onClick(() => { this.selected = n })
              }
            }, (n: KnowNode) => n.id)
          }
          .width('100%')
          .height('100%')
          .padding({ left: 20, right: 20, top: 10, bottom: 10 })
        }

        // 详情面板（06）：有选中节点才显示，叠在右侧
        if (this.selected) {
          this.detailPanel()
          // 关闭按钮：叠在详情面板右上角，点了清空 selected，面板消失
          Text('✕')
            .fontSize(18)
            .fontColor('#6b7280')
            .position({ x: '92%', y: '3%' })
            .onClick(() => { this.selected = null })
        }

        // 材料详情页（07）：全屏盖在详情面板上面
        if (this.showMaterial) {
          this.materialPage()
        }

        // 空间内搜索（08）：全屏盖在最上面
        if (this.showSearch) {
          this.searchPage()
        }

        // 新建空间页（03/04）：全屏浮层
        if (this.showCreate) {
          this.createSpacePage()
        }
      }
    }
  }

  // ═══ 06 节点详情面板（内容变多了，用 Scroll 包起来，少了能滚动）═══
  @Builder
  detailPanel() {
    Column() {
      Scroll() {
        Column() {
          Text(this.selected!.name).fontSize(18).fontWeight(FontWeight.Bold)
          Text(`${this.selected!.type} · ${statusText(this.selected!.status)}`).fontSize(12).fontColor('#6b7280').margin({ top: 4 })

          // 状态行：任务状态 与 理解状态 分开记（06 要求）
          Row() {
            Column() {
              Text('任务状态').fontSize(11).fontColor('#9aa3b2')
              Text(statusText(this.selected!.status)).fontSize(13).fontWeight(FontWeight.Medium).margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)

            Column() {
              Text('理解状态').fontSize(11).fontColor('#9aa3b2')
              Text(this.selectedUnderstood === 'yes' ? '已理解' : '未理解')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.selectedUnderstood === 'yes' ? '#1a9e5c' : '#b45309')
                .margin({ top: 2 })
            }
            .alignItems(HorizontalAlign.Start)

            Button(this.selectedUnderstood === 'yes' ? '标为未理解' : '标为已理解')
              .fontSize(12)
              .height(28)
              .onClick(() => { this.toggleUnderstood() })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
          .margin({ top: 12 })

          // 原始资料：整块可点，点它打开材料详情页（07）
          Column() {
            Text('原始资料').fontSize(12).fontColor('#4f6bed').fontWeight(FontWeight.Bold)
            Text(this.selected!.res).fontSize(13).margin({ top: 4 })
            Text('点击查看材料详情 →').fontSize(11).fontColor('#4f6bed').margin({ top: 6 })
          }
          .onClick(() => { this.showMaterial = true })
          .alignItems(HorizontalAlign.Start)
          .padding(10)
          .margin({ top: 10 })
          .border({ width: 1, color: '#d8dee9' })
          .borderRadius(10)
          .width('100%')

          this.block('样例补充', this.selected!.example)

          // 个人笔记：可编辑（点“编辑”改字，点“保存”写回数据）
          Column() {
            Row() {
              Text('个人笔记').fontSize(12).fontColor('#4f6bed').fontWeight(FontWeight.Bold)
              if (!this.noteEditing) {
                Button('编辑')
                  .fontSize(12)
                  .height(28)
                  .onClick(() => {
                    this.noteDraft = this.selected!.note
                    this.noteEditing = true
                  })
              } else {
                Button('保存')
                  .fontSize(12)
                  .height(28)
                  .onClick(() => {
                    // selected 指向的就是 NODES 里同一个对象，改它=改数据本身
                    this.selected!.note = this.noteDraft
                    this.noteEditing = false
                  })
              }
            }
            .justifyContent(FlexAlign.SpaceBetween)
            .width('100%')

            if (!this.noteEditing) {
              Text(this.selected!.note).fontSize(13).margin({ top: 4 })
            } else {
              TextInput({ text: this.noteDraft })
                .onChange((v: string) => { this.noteDraft = v })
                .width('100%')
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          .padding(10)
          .margin({ top: 10 })
          .border({ width: 1, color: '#d8dee9' })
          .borderRadius(10)
          .width('100%')

          this.block('练习记录', this.selected!.practice)

          // 关联任务：每个任务单独一行（06 要求分开展示）
          Column() {
            Text('关联任务').fontSize(12).fontColor('#4f6bed').fontWeight(FontWeight.Bold)
            ForEach(this.selected!.tasks, (t: string) => {
              Row() {
                Text('· ' + t).fontSize(13)
              }
              .width('100%')
              .margin({ top: 4 })
            }, (t: string) => t)
          }
          .alignItems(HorizontalAlign.Start)
          .padding(10)
          .margin({ top: 10 })
          .border({ width: 1, color: '#d8dee9' })
          .borderRadius(10)
          .width('100%')

          // 相关节点：前置 / 后续（05 要求“节点与关系清晰”）
          Column() {
            Text('相关节点').fontSize(12).fontColor('#4f6bed').fontWeight(FontWeight.Bold)
            Text(this.prevText(this.selected!)).fontSize(13).margin({ top: 4 })
            Text(this.nextText(this.selected!)).fontSize(13).margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .padding(10)
          .margin({ top: 10 })
          .border({ width: 1, color: '#d8dee9' })
          .borderRadius(10)
          .width('100%')
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
    }
    .padding(20)
    .width('32%')
    .height('100%')
    .position({ x: '68%', y: '0' })
    .backgroundColor('#ffffff')
    .border({ width: 1, color: '#d8dee9' })
  }

  // 通用的“资料块”：标题 + 内容（样例补充、练习记录用）
  @Builder
  block(title: string, content: string) {
    Column() {
      Text(title).fontSize(12).fontColor('#4f6bed').fontWeight(FontWeight.Bold)
      Text(content).fontSize(13).margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(10)
    .margin({ top: 10 })
    .border({ width: 1, color: '#d8dee9' })
    .borderRadius(10)
    .width('100%')
  }

  // 换了节点：把新节点的理解状态同步进来，顺便退出笔记编辑态（@Watch 回调）
  syncUnderstood(): void {
    this.selectedUnderstood = this.selected === null ? 'no' : this.selected!.understood
    this.noteEditing = false   // 换节点时退出编辑态，免得看到上一个节点的草稿
  }

  // 理解状态开关：数据本身和界面状态一起改（两个都要改，界面才会刷新）
  toggleUnderstood(): void {
    const next: string = this.selectedUnderstood === 'yes' ? 'no' : 'yes'
    this.selected!.understood = next
    this.selectedUnderstood = next
  }

  // ═══ 07 学习材料详情页：能看正文和来源，能回来源节点 ═══
  @Builder
  materialPage() {
    Column() {
      Row() {
        Text(this.selected!.res).fontSize(17).fontWeight(FontWeight.Bold)
        Button('↑ 返回').onClick(() => { this.showMaterial = false })
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .width('100%')

      Text('正文').fontSize(13).fontColor('#4f6bed').margin({ top: 16 })
      Text(this.selected!.matBody).fontSize(14).margin({ top: 4 })

      Text('来源').fontSize(13).fontColor('#4f6bed').margin({ top: 16 })
      Text(this.selected!.matFrom).fontSize(13).fontColor('#6b7280').margin({ top: 4 })

      Button('↑ 回到来源节点：' + this.selected!.name)
        .width('100%')
        .margin({ top: 24 })
        .onClick(() => { this.showMaterial = false })
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor('#ffffff')
    .alignItems(HorizontalAlign.Start)
  }

  // ═══ 08 空间内搜索：关键词 + 按分类筛选，空结果一键恢复 ═══
  @Builder
  searchPage() {
    Column() {
      // 顶栏：标题 + 取消
      Row() {
        Text('空间内搜索').fontSize(18).fontWeight(FontWeight.Bold)
        Button('取消').onClick(() => { this.showSearch = false })
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .width('100%')

      // 关键词输入框（边打边筛）
      TextInput({ placeholder: '搜索关键词（名字/资料/笔记/练习）', text: this.searchKeyword })
        .width('100%')
        .margin({ top: 12 })

      // 分类页签：全部 / 知识 / 笔记 / 练习（选中的变蓝）
      Row() {
        Button('全部').fontSize(13).margin(4)
          .backgroundColor(this.searchTab === 'all' ? '#4f6bed' : '#e8edf5')
          .fontColor(this.searchTab === 'all' ? '#ffffff' : '#374151')
          .onClick(() => { this.searchTab = 'all' })
        Button('知识').fontSize(13).margin(4)
          .backgroundColor(this.searchTab === 'know' ? '#4f6bed' : '#e8edf5')
          .fontColor(this.searchTab === 'know' ? '#ffffff' : '#374151')
          .onClick(() => { this.searchTab = 'know' })
        Button('笔记').fontSize(13).margin(4)
          .backgroundColor(this.searchTab === 'note' ? '#4f6bed' : '#e8edf5')
          .fontColor(this.searchTab === 'note' ? '#ffffff' : '#374151')
          .onClick(() => { this.searchTab = 'note' })
        Button('练习').fontSize(13).margin(4)
          .backgroundColor(this.searchTab === 'practice' ? '#4f6bed' : '#e8edf5')
          .fontColor(this.searchTab === 'practice' ? '#ffffff' : '#374151')
          .onClick(() => { this.searchTab = 'practice' })
      }
      .margin({ top: 8 })

      // 结果区：有结果→列表；空结果→提示 + 一键恢复
      if (this.searchResults().length === 0) {
        Column() {
          Text('没有找到匹配的内容').fontSize(15).fontColor('#6b7280')
          Text('换个关键词，或点下面按钮看全部').fontSize(12).fontColor('#9ca3af').margin({ top: 6 })
          Button('清空筛选，看全部')
            .margin({ top: 16 })
            .onClick(() => {
              this.searchKeyword = ''
              this.searchTab = 'all'
            })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.searchResults(), (n: KnowNode) => {
            ListItem() {
              Column() {
                Text(n.name).fontSize(15).fontWeight(FontWeight.Medium)
                Text(this.matchLabel(n)).fontSize(12).fontColor('#6b7280').margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(12)
              .backgroundColor('#ffffff')
              .border({ width: 1, color: '#d8dee9' })
              .borderRadius(12)
              .onClick(() => {
                this.selected = n
                this.showSearch = false   // 关掉搜索页，直接打开这个节点的详情
              })
            }
          }, (n: KnowNode) => n.id)
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ top: 12 })
      }
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f7fa')
    .alignItems(HorizontalAlign.Start)
  }

  // 搜索结果：按页签决定搜哪些字段；关键词为空 = 看该分类全部
  searchResults(): KnowNode[] {
    const kw: string = this.searchKeyword.trim()
    const out: KnowNode[] = []
    for (let i = 0; i < this.nodes.length; i++) {
      const n: KnowNode = this.nodes[i]
      let text: string = ''
      if (this.searchTab === 'know') {
        text = n.name + n.type + n.desc + n.res
      } else if (this.searchTab === 'note') {
        text = n.note
      } else if (this.searchTab === 'practice') {
        text = n.practice
      } else {
        text = n.name + n.type + n.desc + n.res + n.note + n.practice
      }
      if (kw === '' || text.indexOf(kw) >= 0) {
        out.push(n)
      }
    }
    return out
  }

  // 结果列表里显示“匹配到的那条内容”
  matchLabel(n: KnowNode): string {
    if (this.searchTab === 'note') {
      return '笔记：' + n.note
    }
    if (this.searchTab === 'practice') {
      return '练习：' + n.practice
    }
    return n.res
  }

  // ═══ 关系展示：用文字把“前置/后续”讲清楚（不画线，零风险）═══
  nodeById(id: string): KnowNode {
    for (let i = 0; i < this.nodes.length; i++) {
      if (this.nodes[i].id === id) {
        return this.nodes[i]
      }
    }
    return this.nodes[0]
  }

  // 地图节点下方的小字：这个节点指向谁（→ 后续1 后续2）
  mapRelText(n: KnowNode): string {
    let out: string = ''
    for (let i = 0; i < EDGES.length; i++) {
      if (EDGES[i].from === n.id) {
        out = out + '→' + this.nodeById(EDGES[i].to).name + ' '
      }
    }
    return out
  }

  // 详情面板用：这个节点的前置节点们（谁指向它）
  prevText(n: KnowNode): string {
    let out: string = '前置：'
    let found: boolean = false
    for (let i = 0; i < EDGES.length; i++) {
      if (EDGES[i].to === n.id) {
        out = out + this.nodeById(EDGES[i].from).name + '、'
        found = true
      }
    }
    if (!found) {
      return '前置：（无，这是起点）'
    }
    return out
  }

  // 详情面板用：这个节点的后续节点们（它指向谁）
  nextText(n: KnowNode): string {
    let out: string = '后续：'
    let found: boolean = false
    for (let i = 0; i < EDGES.length; i++) {
      if (EDGES[i].from === n.id) {
        out = out + this.nodeById(EDGES[i].to).name + '、'
        found = true
      }
    }
    if (!found) {
      return '后续：（无，这是终点）'
    }
    return out
  }

  // ═══ 新建学习空间（03 表单 + 04 预览确认）═══

  // 新建页外壳：顶栏 + 按 createMode 切换“表单/预览”
  @Builder
  createSpacePage() {
    Column() {
      Row() {
        Text('新建学习空间').fontSize(18).fontWeight(FontWeight.Bold)
        Button('取消').onClick(() => { this.showCreate = false })
      }
      .justifyContent(FlexAlign.SpaceBetween)
      .width('100%')

      if (this.createMode === 'form') {
        this.createForm()
      } else {
        this.createPreview()
      }
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f7fa')
    .alignItems(HorizontalAlign.Start)
  }

  // 表单部分（03）
  @Builder
  createForm() {
    Column() {
      Text('学习目标 *').fontSize(13).fontColor('#4f6bed')
      TextInput({ placeholder: '想弄懂什么？', text: this.goalDraft })
        .onChange((v: string) => { this.goalDraft = v })
        .width('100%')
        .margin({ top: 4 })

      Text('学习材料').fontSize(13).fontColor('#4f6bed').margin({ top: 16 })
      TextInput({ placeholder: '课件 / 文档链接', text: this.materialDraft })
        .onChange((v: string) => { this.materialDraft = v })
        .width('100%')
        .margin({ top: 4 })

      Text('目标时间').fontSize(13).fontColor('#4f6bed').margin({ top: 16 })
      TextInput({ placeholder: '如 2026-11-30', text: this.timeDraft })
        .onChange((v: string) => { this.timeDraft = v })
        .width('100%')
        .margin({ top: 4 })

      // 校验不通过时，红字提示
      if (this.createError !== '') {
        Text(this.createError).fontSize(12).fontColor('#ff4d4f').margin({ top: 12 })
      }

      Button('下一步：预览')
        .width('100%')
        .margin({ top: 24 })
        .onClick(() => { this.checkCreate() })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 校验：三项都填了才让进预览
  checkCreate(): void {
    if (this.goalDraft.trim() === '') {
      this.createError = '学习目标还没填'
      return
    }
    if (this.materialDraft.trim() === '') {
      this.createError = '学习材料还没填'
      return
    }
    if (this.timeDraft.trim() === '') {
      this.createError = '目标时间还没填'
      return
    }
    this.createError = ''
    this.createMode = 'preview'
  }

  // 预览确认部分（04）
  @Builder
  createPreview() {
    Column() {
      Text('确认一下').fontSize(15).fontWeight(FontWeight.Bold)
      this.createSummaryRow('学习目标', this.goalDraft)
      this.createSummaryRow('学习材料', this.materialDraft)
      this.createSummaryRow('目标时间', this.timeDraft)

      Row() {
        Button('返回修改').margin(8).onClick(() => { this.createMode = 'form' })
        Button('确认创建').margin(8).onClick(() => { this.confirmCreate() })
      }
      .margin({ top: 20 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  createSummaryRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(13).fontColor('#6b7280').width(80)
      Text(value).fontSize(14)
    }
    .width('100%')
    .margin({ top: 12 })
    .padding(10)
    .backgroundColor('#ffffff')
    .borderRadius(8)
  }

  // 确认创建：把新空间作为节点加到地图上，然后清空草稿、关页面回地图
  confirmCreate(): void {
    const newNode: KnowNode = {
      id: 'n' + (this.nodes.length + 1).toString(),
      name: this.goalDraft,
      type: '空间',
      status: 'todo',
      understood: 'no',
      x: 12,
      y: 10 + this.nodes.length * 8,
      desc: '我新建的学习空间',
      res: this.materialDraft,
      matBody: '我创建的学习空间，资料整理中。',
      matFrom: '我上传的学习材料',
      example: '',
      note: '',
      practice: '截止：' + this.timeDraft,
      tasks: ['开始学习：' + this.goalDraft]
    }
    this.nodes.push(newNode)
    this.goalDraft = ''
    this.materialDraft = ''
    this.timeDraft = ''
    this.createMode = 'form'
    this.createError = ''
    this.showCreate = false
  }
}
