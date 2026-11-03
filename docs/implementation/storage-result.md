# 文档命令、存储与导出交付

已按 `CONTRACT.md` 与所附 ArkTS/API 24 技能实施，未改共享类型、页面、入口和公共构建配置，未提交 Git。

## 已实现

- `DocumentSession`：所有命令先复制后校验再替换；根节点、父节点、唯一 ID、无环、1–500 节点、最多8层、消息与字段格式校验。失败不改变原文档。增加/同级/删除子树/移动/编辑/折叠/布局/重命名均支持撤销重做。历史保留100步。每次修改及撤销重做的 revision 单调递增；AI候选校验文档ID与baseRevision，整次AI应用是一个撤销步骤。
- `DocumentRepository`：使用独立 `mindmaps.db`、S1 RelationalStore；文档、元信息、前一恢复快照在同一事务内保存；新文档首次保存也写恢复快照。写入队列串行执行并捕获调用时快照，拒绝较低revision覆盖；单次失败不阻塞后续写入。标题参数化搜索、本地读取/删除；Preferences 保存偏好后显式flush。初始化并发合并。
- `ExportService`：系统DocumentViewPicker保存PNG/Markdown/JSON，选择JSON恢复；URI通过FileIO读写，处理部分读写和关闭资源；导入严格UTF8、格式和完整领域校验，创建新documentId、重置revision，保留节点ID/源文/对话内容。
- Markdown导出整树（包括折叠节点）、节点备注、原始输入；JSON格式为 `{format:'flowspace-mindmap',version:1,document:...}`，备份上限8MB（UTF8字节），导出超限也明确报错，避免产生自身无法恢复的文件。
- PNG独立计算全树布局，忽略视口/缩放/折叠，支持right/down；使用API24 `drawing.Canvas(PixelMap)` 绘制连线、全部节点与文字，ImagePacker编码PNG；按完整图边界缩放，最长边不超过4096，完成或失败均释放PixelMap和ImagePacker。大图在4096限制下会缩小，Markdown/JSON可保留完整文本用于高密度内容。

## SDK核对

核对本机 `sdk/default/openharmony/ets/api/` 中 RelationalStore `querySql/executeSql/beginTransaction/commit/rollBack`、Preferences `getPreferences/get/put/flush`、FileIO `open/read/write/stat/close`、DocumentViewPicker、Drawing Canvas/Font/TextBlob、Image PixelMap/ImagePacker、util TextDecoder/TextEncoder声明。

## 测试

`node --test tools/tests/domain-session.mjs`：10项通过。测试使用Node24的TypeScript类型剥离直接运行真实源码逻辑，未复制命令实现：

1. 不可变命令、revision单调撤销重做、分叉后清空redo。
2. 同级节点、删除子树、循环移动失败不改图、根不能删除移动。
3. 第九层与第501节点失败不改图。
4. 重复ID、孤儿、错误根、空节点、坏消息等非法文档拒绝。
5. 过期AI候选拒绝、跨文档候选拒绝、整次AI一次撤销。
6. JSON往返生成新ID、保留内容，坏备份/坏结构拒绝。
7. Markdown含折叠节点、备注、源文。
8. 模拟系统绘图接口验证500节点均绘制、两种方向最长边4096、资源释放。
9. 撤销、重做与AI应用仅回滚/替换图内容，保留当前完整对话与原文；AI候选只含近期20条时仍不会截断本地120条历史。
10. 领域 ID128/节点文字500/原文20000/单消息20000/日期64/角色user-assistant与AI字段限制一致；本地可保存1000条对话，网络请求由集成层截取最近20条。

测试第8项使用图形API替身验证调用和边界，不宣称验证了真实PNG像素或设备行为。RelationalStore、Preferences、系统文件选择器及PNG实机成像仍需主线程编译和设备验收；本模块未单独运行SDK构建以免与并行集成构建冲突。

## 存储替身独立验证（10项）

`node --test tools/tests/document-repository.mjs`：10项通过。测试转译并执行实际 `DocumentRepository.ets`，没有复制仓库保存/查询算法。仅替换系统RDB与Preferences边界；替身严格限定允许SQL、参数数目、结果列类型、游标关闭、事务边界及SQL不可重叠，未知SQL直接失败。故障在文档更新之后、事务提交之前注入，用于验证真实仓库catch/rollback与后续队列恢复。

1. 并发初始化合并且重复初始化不会重复打开存储。
2. 并发保存按调用顺序执行，外部后续修改不影响已捕获保存快照。
3. 查询等待写入完成，旧revision拒绝后后续保存仍可成功。
4. 文档更新后注入事务失败，当前文档与恢复快照均回滚，重试可成功。
5. 损坏JSON、空payload、非法树结构、错误文档身份均从有效快照恢复；快照本身损坏或缺失明确失败。
6. 修复损坏当前稿时保留此前有效恢复快照，避免将坏payload覆盖进去。
7. 参数化标题搜索与更新时间排序；删除同时移除当前稿和快照。
8. 删除第二张表前注入失败，两表回滚，后续删除重试成功。
9. 设置flush后重建仓库/Preferences仍可读取；flush失败向调用方报告，可重试；错误地址拒绝。
10. 非法文档在任何SQL写入前被拒绝。

该轮验证发现并修复三个实现缺陷：空payload被误判为不存在、文档身份未校验、损坏当前稿污染有效快照。此为Node进程内替身验证，不是设备或SQLite系统实现测试，不证明真实RDB崩溃恢复、锁行为或Preferences设备落盘已验收。
