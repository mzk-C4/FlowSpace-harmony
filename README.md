# FlowSpace-harmony

面向大学生的鸿蒙学习工作台。当前主工程位于根目录 `entry/`，使用 ArkTS / ArkUI。

已集中首页与设置、知识地图、行动练习与对比、时间安排模块。当前数据以 Mock 为主，跨模块数据和后端接入仍需联调。

- 分工与验收：[requirements.md](requirements.md)
- 合并结果、现存缺口、成员下一步和三条验收流程：[合并后联调计划](docs/合并后联调计划.md)
- 时间安排接口与手工验收：[黄崇杰模块交付说明](docs/黄崇杰模块交付说明.md)

用匹配 API 26 的 DevEco Studio 打开仓库根目录，配置本机 SDK 和签名后构建运行。静态集成检查：`node tools/check-integration.mjs`。真实构建及设备验收状态见联调计划。
