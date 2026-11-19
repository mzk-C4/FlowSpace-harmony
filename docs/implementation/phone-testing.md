# 真机测试路径与本机验证

2026-11-19：本机实际 `hdc list targets` 无设备。现有 `entry-default-unsigned.hap` 经官方 `hap-sign-tool.jar verify-app` 验证失败。因此本次没有完成真实签名构建、安装、启动或手机点击测试。以下脚本提供真实可执行入口，配置和设备由用户提供。

## 1. 准备本应用的合法签名

在仓库外建立本项目的 DevEco 本机签名工程副本，保持 `AppScope/app.json5` 的 bundleName 为 `com.mzk.flowspace`，使用用户自己的开发者身份与合法证书/profile，并在 DevEco 中授权当前测试手机。先通过本机 DevEco 的签名配置检查。不要借用其他应用的密钥，不要将证书、profile、密码或整个签名配置加入 Git。

构建脚本只接收这个外部工程目录，通过本机官方构建依赖解析 JSON5，核对相同 bundleName、签名配置名及必要材料文件。只把 signingConfigs 合入本项目临时构建配置，保留本项目的 API24 与源码；证书/profile/密钥路径解析为外部工程的绝对路径。不会创建证书。配置文件路径存在不代表凭据有效，实际签名须构建并验签后才成立。

```powershell
# 先看当前 unsigned 构建前置条件；不构建、不改设备
./tools/build-harmony.ps1 -DryRun

# 用户替换为自己的同bundleName外部DevEco工程；可指定实际配置名
./tools/build-harmony.ps1 -SigningProject 'C:/Users/HP/LocalProjects/FlowSpace-Signing' -SigningConfigName default -DryRun
./tools/build-harmony.ps1 -SigningProject 'C:/Users/HP/LocalProjects/FlowSpace-Signing' -SigningConfigName default -OutputDirectory 'C:/Users/HP/LocalProjects/FlowSpace-Hap'
```

签名构建使用只授权当前用户的临时目录，抑制可能包含凭据的原始构建输出，完成或失败后删除该临时目录。输出中的 `VerifiedSignedHaps` 只包含通过官方 `verify-app -inFile ... -outCertChain ... -outProfile ...` 的指定包；不能凭文件名含 signed 判断。没有 SigningProject 时构建仍可产生 unsigned 编译产物，状态明确为 UnsignedBuilt，不能用于本脚本的手机安装。

## 2. 连接、预检与更新安装

解锁手机并允许USB调试授权。多设备必须明确传 `-DeviceId`，ID复制自本机工具 `hdc list targets`，不自动选第一台。HAP 必须是本应用，脚本会读取实际包内 module.json 核对 bundleName，并重新执行官方验签。

```powershell
./tools/test-phone.ps1 -DryRun
./tools/test-phone.ps1 -Hap 'C:/Users/HP/LocalProjects/FlowSpace-Hap/用户实际产物.hap' -DeviceId '用户手机connect-key' -DryRun
./tools/test-phone.ps1 -Hap 'C:/Users/HP/LocalProjects/FlowSpace-Hap/用户实际产物.hap' -DeviceId '用户手机connect-key' -MapGateway
```

DryRun只核对本机工具、设备列表、HAP身份与签名，不执行设备shell、映射、安装或启动；其ReadyForDevicePreflight也不等于设备运行已验收。正式执行随后核对设备 `const.ohos.apiversion >= 24` 与手机类型，检查设备自身 aa/bm help，再运行 `hdc -t ID install -r HAP` 更新安装。安装或签名不兼容时停止，绝不自动卸载、清数据或换证书重装。之后读取 bm 包/EntryAbility，启动并从 aa dump 核对实际包与Ability运行证据：要求同一 `AbilityRecord ID #N` 记录内连续的 `main name [EntryAbility]` 与 `bundle name [com.mzk.flowspace]` 字段，不能将两个应用的名字拼接为成功；未知输出布局明确失败、待人工核对。格式依据为 [OpenHarmony AbilityRecord::Dump / DumpAbilityState 源码](https://github.com/openharmony/ability_ability_runtime/blob/master/services/abilitymgr/src/ability_record.cpp)，命令含义见[官方 aa 工具文档](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/aa-tool/)。

当前没有设备，手机端 aa/bm/param 命令分支尚未实机执行。脚本会在正式执行时先检查实际帮助和返回值，未得到证据明确失败。InstalledAndAbilityObserved仅表示包/Ability启动已观察，不声称UI截图、点击、AI或导出成功。

## 3. USB访问电脑本地模型网关

本机实际 `hdc -h` 定义为 `rport remotenode localnode`（手机到电脑反向映射）。因此 `-MapGateway -GatewayPort 8787` 调用 `hdc -t ID rport tcp:8787 tcp:8787`，手机应用后端地址设为 `http://127.0.0.1:8787`。先在电脑本机启动真实网关并配置用户自己的模型地址、模型名与密钥；不用公网监听，也不把上游密钥写进手机或脚本。

重复映射若设备返回错误，脚本停止并提示检查；不要自动删除用户已有的其他转发。映射列表及精确移除命令以本机 `hdc fport ls`、`hdc -h` 为准。USB拔线或hdc重启后需重新检查映射。

## 4. 回归结果与边界

```powershell
./tools/tests/phone-workflow.ps1
```

本机 PowerShell 7 已执行25项专项回归，全部通过：原14项覆盖脚本语法、unsigned dryrun标记、无设备待办/非dry拒绝、多设备显式选择、不存在设备、设备ID与端口校验、缺失HAP、真实官方工具拒绝当前unsigned HAP、不同bundleName签名配置拒绝、缺签名材料拒绝，以及所有被阻止路径未执行设备变更命令；新增11项覆盖官方同记录字段、CRLF、跨应用/跨记录/跨Mission拒绝、包名前缀和Ability子串拒绝、无记录头及无关文本拒绝、后续合法记录识别，以及正式工作流确实调用此严格解析器。

回归中的设备列表来自严格 hdc 边界替身，签名拒绝使用真实本机官方Java工具与真实unsigned包。未制作假签名、未生成证书、未使用其他项目凭据、未运行并行完整构建。成功签名、真实install -r、设备端授权/API检查、实际Ability及UI仍需用户接机后验收。首轮应先确认现有数据仍在，再测自然语言生成、对话改图、重启恢复、JSON/PNG/Markdown文件选择和打开。
