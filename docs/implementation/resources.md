# 资料库官方来源与许可核验（陈珂睿）

本轮复核：2026-11-23（Asia/Shanghai）。共 13 项资料；本轮登记的 28 个入口、许可与独立代码许可链接均为 HTTP GET 200。该结果只证明本机网络下核验时可达，不等于中国大陆所有网络、系统浏览器、真机小屏或全文阅读均通过。

资料范围沿用分工清单。页面仅登记原创简介和原站链接，不自动下载教材、抓取整站或再分发内容。公开访问、开放内容许可、软件开源许可分别记录；含 NC 的材料明确限非商业；OSTEP 保留为公开阅读对照，不认定开放再分发。

本轮修订：Think DSP 的 README 声明教材 CC BY-NC-SA 4.0，独立 LICENSE 明确软件 MIT；已增加单独的代码许可入口。D2L 继续准确标注 modified MIT；SymPy 按本轮 LICENSE 写为主许可 BSD-3-Clause，个别文件与第三方另核。

## 核验方法与证据

1. 对 13 项的官方入口、许可页和独立代码许可 URL 执行 GET，遵循 TLS 校验与 HTTPS 重定向。
2. 阅读 D2L README/两类许可、Think DSP README/LICENSE、Missing Semester 许可、MIT OCW 条款、CP-Algorithms 正文声明/LICENSE、KiCad 多类许可与其他项目的 LICENSE。
3. 机器记录保存 HTTP 状态、最终 URL、时间和错误；人工首次复核的短许可文件另有 SHA-256 记录，不打包网页或教材全文。
4. 分类、关键词、无结果、重置、内容/代码许可菜单和主题回调另由源码测试与原生组件截图验证。

## 13 项资料登记

### 动手学深度学习 · D2L

- resourceId：`d2l`
- 分类 / 资料类型：开放教材 / 开放教材与代码（开放教材）
- 介绍：将线性代数、神经网络与可运行实验连起来学习。适合按“数学基础 → 模型 → 训练 → 应用”整理知识。
- 提供方：D2L 作者与 d2l-ai 官方仓库
- 语言：英语
- 原始 URL：[https://github.com/d2l-ai/d2l-en](https://github.com/d2l-ai/d2l-en)
- 内容 / 项目许可依据：[https://github.com/d2l-ai/d2l-en#license-summary](https://github.com/d2l-ai/d2l-en#license-summary)
- 独立代码许可：[https://github.com/d2l-ai/d2l-en/blob/master/LICENSE-SAMPLECODE](https://github.com/d2l-ai/d2l-en/blob/master/LICENSE-SAMPLECODE)
- 许可与范围：教材：CC BY-SA 4.0；示例与参考代码：modified MIT（见 LICENSE-SAMPLECODE，非标准 MIT）。第三方材料以各自声明为准。
- 访问条件：免费公开访问；本轮 HTTP GET 200。系统浏览器与移动网络可用性需在设备上确认。
- 本轮核验日期：2026-11-23；3 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

### Think DSP · 用 Python 学信号处理

- resourceId：`thinkdsp`
- 分类 / 资料类型：开放教材 / 开放教材（限非商业）（开放教材）
- 介绍：从波形、频谱到滤波和卷积，通过 Python 笔记本建立数字信号处理直觉。建议先掌握基础微积分。
- 提供方：作者 Allen B. Downey 官方仓库
- 语言：英语
- 原始 URL：[https://github.com/AllenDowney/ThinkDSP](https://github.com/AllenDowney/ThinkDSP)
- 内容 / 项目许可依据：[https://github.com/AllenDowney/ThinkDSP#readme](https://github.com/AllenDowney/ThinkDSP#readme)
- 独立代码许可：[https://github.com/AllenDowney/ThinkDSP/blob/master/LICENSE](https://github.com/AllenDowney/ThinkDSP/blob/master/LICENSE)
- 许可与范围：教材：CC BY-NC-SA 4.0（含非商业限制）；仓库配套软件：MIT（见 LICENSE）；教材与代码分别适用各自条款。
- 访问条件：免费公开访问；本轮 HTTP GET 200。系统浏览器与移动网络可用性需在设备上确认。
- 本轮核验日期：2026-11-23；3 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

### Missing Semester · 开发工具基础

- resourceId：`missing`
- 分类 / 资料类型：课程仓库 / 开放课程（限非商业）（开放课程）
- 介绍：补齐 Shell、Git、调试、自动化和命令行工具基础。适合整理一份可逐项练习的开发工具路线。
- 提供方：Missing Semester 课程团队官方仓库
- 语言：英语
- 原始 URL：[https://github.com/missing-semester/missing-semester](https://github.com/missing-semester/missing-semester)
- 内容 / 项目许可依据：[https://missing.csail.mit.edu/license/](https://missing.csail.mit.edu/license/)
- 许可与范围：官方许可页声明：课程内容、网站源码、讲义、练习和视频均为 CC BY-NC-SA 4.0；含非商业限制，不标为 OSI 软件开源许可。
- 访问条件：免费公开访问；本轮 HTTP GET 200。系统浏览器与移动网络可用性需在设备上确认。
- 本轮核验日期：2026-11-23；2 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

### MIT 6.006 · 算法导论

- resourceId：`mit6006`
- 分类 / 资料类型：课程仓库 / 开放课件（限非商业）（开放课程）
- 介绍：本科算法课程，覆盖数据结构、排序、图和动态规划，提供讲义、作业与考试材料。
- 提供方：MIT OpenCourseWare
- 语言：英语
- 原始 URL：[https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-fall-2011/](https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-fall-2011/)
- 内容 / 项目许可依据：[https://ocw.mit.edu/pages/privacy-and-terms-of-use/](https://ocw.mit.edu/pages/privacy-and-terms-of-use/)
- 许可与范围：OCW 课程材料：CC BY-NC-SA 4.0，另行标注及第三方内容除外；独立软件与外链代码以各自来源条款为准。
- 访问条件：免费公开访问；本轮 HTTP GET 200。系统浏览器与移动网络可用性需在设备上确认。
- 本轮核验日期：2026-11-23；2 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

### CP-Algorithms · 算法知识手册

- resourceId：`cpalg`
- 分类 / 资料类型：算法 / 开放技术文章（开放文章）
- 介绍：按图论、字符串、数据结构、数论与几何组织的算法文章。适合复习算法之间的前置关系。
- 提供方：CP-Algorithms 官方项目
- 语言：英语
- 原始 URL：[https://cp-algorithms.com/](https://cp-algorithms.com/)
- 内容 / 项目许可依据：[https://github.com/cp-algorithms/cp-algorithms/blob/main/LICENSE](https://github.com/cp-algorithms/cp-algorithms/blob/main/LICENSE)
- 许可与范围：文章正文：CC BY-SA 4.0（网站页脚明确声明）；代码片段的独立软件许可：以来源页条款为准，不推定为 MIT。
- 访问条件：免费公开访问；本轮 HTTP GET 200。系统浏览器与移动网络可用性需在设备上确认。
- 本轮核验日期：2026-11-23；2 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

### The Algorithms · Python 算法实现

- resourceId：`algpython`
- 分类 / 资料类型：算法 / 开源代码（开源代码）
- 介绍：包含排序、搜索、图算法和数值算法的 Python 示例。适合对照概念阅读实现，再自行编写测试。
- 提供方：The Algorithms 官方组织仓库
- 语言：英语 / Python
- 原始 URL：[https://github.com/TheAlgorithms/Python](https://github.com/TheAlgorithms/Python)
- 内容 / 项目许可依据：[https://github.com/TheAlgorithms/Python/blob/master/LICENSE.md](https://github.com/TheAlgorithms/Python/blob/master/LICENSE.md)
- 许可与范围：仓库代码：MIT；不将该许可扩展到仓库链接的外部教材或第三方资源。
- 访问条件：免费公开访问；本轮 HTTP GET 200。系统浏览器与移动网络可用性需在设备上确认。
- 本轮核验日期：2026-11-23；2 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

### OSTEP · 操作系统三大主题

- resourceId：`ostep`
- 分类 / 资料类型：系统 / 免费在线教材（非开源认定）（公开阅读资料）
- 介绍：围绕虚拟化、并发与持久化讲解操作系统。作者提供分章免费在线阅读，可配合实验建立概念图。
- 提供方：威斯康星大学麦迪逊分校 · 作者官网
- 语言：英语
- 原始 URL：[https://pages.cs.wisc.edu/~remzi/OSTEP/](https://pages.cs.wisc.edu/~remzi/OSTEP/)
- 内容 / 项目许可依据：[https://pages.cs.wisc.edu/~remzi/OSTEP/](https://pages.cs.wisc.edu/~remzi/OSTEP/)
- 许可与范围：以来源页条款为准。已确认作者提供免费分章阅读，未据此认定教材具有开放再分发许可；实验代码需另查各仓库许可。
- 访问条件：作者提供免费分章阅读；未认定教材有开放再分发许可。本轮 HTTP GET 200。
- 本轮核验日期：2026-11-23；2 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

### xv6 · RISC-V 教学操作系统

- resourceId：`xv6`
- 分类 / 资料类型：系统 / 开源教学系统（开源代码）
- 介绍：小型 Unix 风格教学系统，可沿进程、页表、系统调用与文件系统阅读源码。适合学过 C 语言后使用。
- 提供方：MIT PDOS 官方仓库
- 语言：英语 / C
- 原始 URL：[https://github.com/mit-pdos/xv6-riscv](https://github.com/mit-pdos/xv6-riscv)
- 内容 / 项目许可依据：[https://github.com/mit-pdos/xv6-riscv/blob/riscv/LICENSE](https://github.com/mit-pdos/xv6-riscv/blob/riscv/LICENSE)
- 许可与范围：本仓库软件及随附文档：MIT 风格许可（见 LICENSE）；外部 xv6 教材与课程材料应另核条款。
- 访问条件：免费公开访问；本轮 HTTP GET 200。系统浏览器与移动网络可用性需在设备上确认。
- 本轮核验日期：2026-11-23；2 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

### KiCad · 电路与 PCB 入门

- resourceId：`kicad`
- 分类 / 资料类型：电子 / 开放文档与开源工具（开放文档）
- 介绍：官方文档包含原理图、PCB 布局与 SPICE 仿真指南，适合建立从元器件到电路板的学习路线。
- 提供方：KiCad 官方文档团队
- 语言：多语言（含中文）
- 原始 URL：[https://docs.kicad.org/](https://docs.kicad.org/)
- 内容 / 项目许可依据：[https://www.kicad.org/about/licenses/](https://www.kicad.org/about/licenses/)
- 许可与范围：文档：GPL-3.0-or-later 或 CC BY 3.0-or-later 二选一；软件主体：GPL-3.0-or-later（另有第三方许可）；元件库另为 CC BY-SA 4.0，细节见官方库条款。
- 访问条件：免费公开访问；本轮 HTTP GET 200。系统浏览器与移动网络可用性需在设备上确认。
- 本轮核验日期：2026-11-23；2 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

### FreeRTOS · 嵌入式实时内核

- resourceId：`freertos`
- 分类 / 资料类型：电子 / 开源嵌入式内核（开源代码）
- 介绍：面向微控制器的实时内核，学习任务调度、队列、信号量与内存管理。适合在掌握 C 与单片机基础后阅读源码。
- 提供方：FreeRTOS 官方组织仓库
- 语言：英语 / C
- 原始 URL：[https://github.com/FreeRTOS/FreeRTOS-Kernel](https://github.com/FreeRTOS/FreeRTOS-Kernel)
- 内容 / 项目许可依据：[https://github.com/FreeRTOS/FreeRTOS-Kernel/blob/main/LICENSE.md](https://github.com/FreeRTOS/FreeRTOS-Kernel/blob/main/LICENSE.md)
- 许可与范围：本内核仓库软件与随附文档：MIT（见 LICENSE.md）；外部文档、演示工程与硬件厂商组件需分别核对许可。
- 访问条件：免费公开访问；本轮 HTTP GET 200。系统浏览器与移动网络可用性需在设备上确认。
- 本轮核验日期：2026-11-23；2 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

### NumPy · 数组与线性代数

- resourceId：`numpy`
- 分类 / 资料类型：数值方法 / 开源科学计算库（开源代码）
- 介绍：科学计算数组基础，覆盖广播、矩阵运算和随机采样。适合梳理数组形状、向量化与线性代数的关系。
- 提供方：NumPy 官方项目仓库
- 语言：英语 / Python
- 原始 URL：[https://github.com/numpy/numpy](https://github.com/numpy/numpy)
- 内容 / 项目许可依据：[https://github.com/numpy/numpy/blob/main/LICENSE.txt](https://github.com/numpy/numpy/blob/main/LICENSE.txt)
- 许可与范围：仓库主许可：BSD-3-Clause；捆绑依赖及第三方代码须遵循各自声明。外部文档不自动套用代码许可。
- 访问条件：免费公开访问；本轮 HTTP GET 200。系统浏览器与移动网络可用性需在设备上确认。
- 本轮核验日期：2026-11-23；2 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

### SciPy · 数值计算工具箱

- resourceId：`scipy`
- 分类 / 资料类型：数值方法 / 开源科学计算库（开源代码）
- 介绍：包含优化、积分、插值、信号处理与线性代数算法，适合按“数学问题 → 数值方法 → 工具”组织知识。
- 提供方：SciPy 官方项目仓库
- 语言：英语 / Python
- 原始 URL：[https://github.com/scipy/scipy](https://github.com/scipy/scipy)
- 内容 / 项目许可依据：[https://github.com/scipy/scipy/blob/main/LICENSE.txt](https://github.com/scipy/scipy/blob/main/LICENSE.txt)
- 许可与范围：仓库主许可：BSD-3-Clause；第三方组件需另查其许可。外链教程和文档不自动套用代码许可。
- 访问条件：免费公开访问；本轮 HTTP GET 200。系统浏览器与移动网络可用性需在设备上确认。
- 本轮核验日期：2026-11-23；2 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

### SymPy · 符号数学与公式推导

- resourceId：`sympy`
- 分类 / 资料类型：数值方法 / 开源符号计算库（开源代码）
- 介绍：用于符号微积分、代数方程与矩阵运算。适合比较精确符号推导与浮点数值计算的适用场景。
- 提供方：SymPy 官方项目仓库
- 语言：英语 / Python
- 原始 URL：[https://github.com/sympy/sympy](https://github.com/sympy/sympy)
- 内容 / 项目许可依据：[https://github.com/sympy/sympy/blob/master/LICENSE](https://github.com/sympy/sympy/blob/master/LICENSE)
- 许可与范围：仓库主许可：BSD-3-Clause；个别文件及第三方内容以各自声明为准。外部材料不自动适用代码许可。
- 访问条件：免费公开访问；本轮 HTTP GET 200。系统浏览器与移动网络可用性需在设备上确认。
- 本轮核验日期：2026-11-23；2 个登记链接均 HTTP 200。
- 移动端原站阅读：尚未逐项在实体机浏览器验收。

## 复查命令

```sh
node tools/verify-resource-links.mjs
node tools/sync-library-preview.mjs
node --test tools/tests/resource-library.mjs
```

机器清单见 `resource-catalog-20261123.json`，网络记录见 `resource-links-20261123.json`。许可文字是范围说明，不替代原站原文。