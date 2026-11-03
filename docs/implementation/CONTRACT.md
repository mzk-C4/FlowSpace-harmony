# FlowSpace 实施合同（各分对话先读）

本目录是新产品，不再使用旧的工作台业务。各协作者共享独立FlowSpace-mindmap工作目录；主对话统一公共配置、提交与构建，协作者不切换分支、不覆盖他人文件。源代码API24；本机SDK位于E:/harmony system/command-line-tools/sdk/default/openharmony/ets/api。先按[设计依据](../设计依据.md)读取指定HarmonyOS与Emil skill，再查真实SDK签名。技能原文的本地缓存不随项目分发。

## 最新产品与成员

四个一级页面：01 首页（赵紫石，工科学习视频收集）；02 DIY 思维导图（黄崇杰）；03 资料库（陈珂睿，收集开放/开源资料）；04 个人（白长林）；马兆坤负责其余公共工程、AI、后端、存储、集成与答辩。仅手机；不做账号/云同步/拍照/OCR/语音。自然语言/长文 → 真实 AI 生成 → 对话修改或手动编辑 → 保存和导出。

## 共享类型与界面

唯一类型定义在 domain/MindMap.ets（主对话维护，其他人不改）。所有 UI 用 @ComponentV2 / @Local / @Param / @Event。@Param 文档不可原地修改，只发回调；主对话替换文档引用。所有 UI 独立组件，无 @Entry、无自己的 Navigation。

所有页面背景暖白、石墨正文、蓝紫重点色，深色通过资源。主对话将提供 app.color.fs_bg / fs_surface / fs_text / fs_muted / fs_border / fs_accent / fs_soft / fs_danger。页面内部不再放重复底部导航（主对话提供四栏）。触控目标最少 44vp，长文和键盘不遮挡按钮。

- ui/HomePage.ets 导出 HomePage：@Param documents:DocumentSummary[]=[]; @Param busy:boolean=false; @Event onGenerate:(text:string)=>void; @Event onOpenDocument:(id:string)=>void; @Event onNewMap:()=>void; @Event onOpenResource:(resource:LearningResource)=>void。完整首页含自然语言输入、示例、最近导图、工科学习视频。视频数据 data/VideoCatalog.ets 导出 VIDEO_RESOURCES:LearningResource[]。仅经实际官方页面核对的链接，标清来源/语言，公开视频≠可自由再分发。
- ui/DIYPage.ets 导出 DIYPage：@Param document:MindMapDocument=createDocument(); @Param selectedNodeId:string=''; @Param canUndo:boolean=false; @Param canRedo:boolean=false; @Param busy:boolean=false; @Param progress:string=''; @Param saveStatus:string='已保存'; @Param candidateSummary:string=''; @Param errorMessage:string=''; @Param reduceMotion:boolean=false; @Event onSelect:(id:string)=>void; @Event onAction:(action:EditorAction)=>boolean; @Event onGenerate:(instruction:string)=>void; @Event onCancel:()=>void; @Event onApplyCandidate:()=>void; @Event onDiscardCandidate:()=>void; @Event onExport:(format:string)=>void。内含画布、节点输入面板、布局/缩放/折叠/适应、对话面板、源文折叠和候选预览确认。action.kind 使用 addChild/addSibling/edit/remove/move/toggle/undo/redo/layout/rename；layout 值放 text（right/down）；其他字段未用填空字符串。删除先用系统确认。根不可删除。画布自行封装在 canvas/ 目录；自己的文档复制只用于预览，不写领域数据。
- ui/LibraryPage.ets 导出 LibraryPage：@Event onOpenResource:(resource:LearningResource)=>void; @Event onUseTopic:(text:string)=>void。资源 data/ResourceCatalog.ets 导出 OPEN_RESOURCES:LearningResource[]。完整分类、搜索、详情、原站入口、基于主题生成（不假装已抓取全文）。收集至少 12 个工科开放/开源资源，确切许可证仅在证据充分时写；未知填“以来源页条款为准”。可公开阅读不等于开源，区分 kind/category 与许可。每个链接核对，记录到 docs/implementation/resources.md。
- ui/ProfilePage.ets 导出 ProfilePage：@Param settings:AppSettings=defaultSettings(); @Param documents:DocumentSummary[]=[]; @Param connectionMessage:string=''; @Event onSaveSettings:(settings:AppSettings)=>void; @Event onCheckConnection:()=>void; @Event onOpenDocument:(id:string)=>void; @Event onRenameDocument:(id:string,title:string)=>void; @Event onDeleteDocument:(id:string)=>void; @Event onImport:()=>void。个人是本地文档与偏好中心，无登录假按钮；含搜索、打开/重命名/删除、JSON恢复、外观/减少动效、后端地址、连接检测与关于。已保存设置 props 变化同步表单。删除系统确认。

## 存储/命令合同

domain/DocumentSession.ets 导出 DocumentSession，constructor(doc:MindMapDocument)；document:MindMapDocument；canUndo():boolean；canRedo():boolean；addNode(parentId,text):string；addSibling(nodeId,text):string；editNode(nodeId,text,note):void；removeNode(nodeId):void；moveNode(nodeId,parentId):void；toggleCollapsed(nodeId):void；setLayout(layout):void；rename(title):void；applyCandidate(candidate:GenerationCandidate):void；undo():void；redo():void。每次图修改（包括撤销）revision单调加一；校验根/循环/重复ID/500节点/8层；失败抛Error且原图不变；AI仅当前revision可应用，一次撤销单元。另导出 validateDocument(doc):void。

storage/DocumentRepository.ets 导出单例 documentRepository：initialize(context:common.UIAbilityContext):Promise<void>; list(query:string=''):Promise<DocumentSummary[]>; get(id:string):Promise<MindMapDocument|null>; save(doc):Promise<void>; delete(id):Promise<void>; loadSettings():Promise<AppSettings>; saveSettings(settings):Promise<void>。新 mindmaps.db，RelationalStore，串行保存避免逆序覆盖；保存时文档和恢复快照事务一致。存储失败抛错。导入非法JSON不可保存。

storage/ExportService.ets 导出单例 exportService：exportDocument(context,doc,format:'png'|'markdown'|'json' 或 string):Promise<void>; importDocument(context):Promise<MindMapDocument>。系统DocumentViewPicker选择位置；JSON导入创建新documentId；PNG全图离屏绘制最长边4096，不能只截图可视区域。另提供 markdown(doc):string、serialize(doc):string、parseBackup(text):MindMapDocument 便于测试。

## AI 协议

Node HTTP 后端独立 backend/（不复制原工作台后端），端口8787。GET /api/health → {configured:boolean,model:string,message:string}。
POST /api/mindmaps/generate 接收 GenerationRequest，SSE采用 data: 单行JSON\n\n：{type:'progress',message:string} / {type:'candidate',candidate:GenerationCandidate} / {type:'error',code:string,message:string} / {type:'done'}。
模型输出完整规范化 document，首次≤200节点/8层，输入≤20000字符，校验失败修复一次；修改只允许 scopeNodeId 子树变动，树外不变；严格校验 baseRevision、稳定ID、无环。create和revise均使用客户端documentId；创建与修改返回baseRevision；最终revision由客户端命令入口递增。不返回模型隐藏推理。环境 LLM_BASE_URL（兼容 /v1 根地址或完整 /chat/completions）、LLM_MODEL、LLM_API_KEY；缺配置明确503。关闭连接取消上游，同文档并发返回409，请求ID避免重复，文档不长期留服务器。服务端 README/.env.example/测试一起交付，不写真实key。

主对话提供 services/GenerationClient.ets 的 generationClient.generate(baseUrl,request,onProgress):Promise<GenerationCandidate> / cancel():void / health(baseUrl):Promise<HealthStatus>，各页面只调用回调，无直接HTTP。

## 交付

各分对话将实施与验证结果写入 docs/implementation/<模块名>-result.md 并最终回复已改文件和限制；不能把未做的真机/真实AI测试写成通过。UI完整可操作，无未实现占位按钮；允许明确配置错误/空态。主对话统一编译修错；不自行修改根工程依赖。
