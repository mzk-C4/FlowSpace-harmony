import { LearningResource } from '../domain/MindMap';

// 人工核验于 2026-11-03。这里只保存原创简介与官方链接，不缓存原站正文。
export const RESOURCE_CATEGORIES: string[] = ['全部', '开放教材', '课程仓库', '算法', '系统', '电子', '数值方法'];

export const OPEN_RESOURCES: LearningResource[] = [
  {
    id: 'd2l', title: '动手学深度学习 · D2L', category: '开放教材',
    description: '将线性代数、神经网络与可运行实验连起来学习。适合按“数学基础 → 模型 → 训练 → 应用”整理知识。',
    url: 'https://github.com/d2l-ai/d2l-en', source: 'D2L 作者与 d2l-ai 官方仓库', language: '英语', kind: '开放教材与代码',
    license: '教材：CC BY-SA 4.0；示例与参考代码：modified MIT（见 LICENSE-SAMPLECODE，非标准 MIT）。第三方材料以各自声明为准。'
  },
  {
    id: 'thinkdsp', title: 'Think DSP · 用 Python 学信号处理', category: '开放教材',
    description: '从波形、频谱到滤波和卷积，通过 Python 笔记本建立数字信号处理直觉。建议先掌握基础微积分。',
    url: 'https://github.com/AllenDowney/ThinkDSP', source: '作者 Allen B. Downey 官方仓库', language: '英语', kind: '开放教材（限非商业）',
    license: '教材：CC BY-NC-SA 4.0（含非商业限制）；配套代码的独立许可：以来源页条款为准，不将教材许可推定为软件许可。'
  },
  {
    id: 'missing', title: 'Missing Semester · 开发工具基础', category: '课程仓库',
    description: '补齐 Shell、Git、调试、自动化和命令行工具基础。适合整理一份可逐项练习的开发工具路线。',
    url: 'https://github.com/missing-semester/missing-semester', source: 'Missing Semester 课程团队官方仓库', language: '英语', kind: '开放课程（限非商业）',
    license: '官方许可页声明：课程内容、网站源码、讲义、练习和视频均为 CC BY-NC-SA 4.0；含非商业限制，不标为 OSI 软件开源许可。'
  },
  {
    id: 'mit6006', title: 'MIT 6.006 · 算法导论', category: '课程仓库',
    description: '本科算法课程，覆盖数据结构、排序、图和动态规划，提供讲义、作业与考试材料。',
    url: 'https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-fall-2011/', source: 'MIT OpenCourseWare', language: '英语', kind: '开放课件（限非商业）',
    license: 'OCW 课程材料：CC BY-NC-SA 4.0，另行标注及第三方内容除外；独立软件与外链代码以各自来源条款为准。'
  },
  {
    id: 'cpalg', title: 'CP-Algorithms · 算法知识手册', category: '算法',
    description: '按图论、字符串、数据结构、数论与几何组织的算法文章。适合复习算法之间的前置关系。',
    url: 'https://cp-algorithms.com/', source: 'CP-Algorithms 官方项目', language: '英语', kind: '开放技术文章',
    license: '文章正文：CC BY-SA 4.0（网站页脚明确声明）；代码片段的独立软件许可：以来源页条款为准，不推定为 MIT。'
  },
  {
    id: 'algpython', title: 'The Algorithms · Python 算法实现', category: '算法',
    description: '包含排序、搜索、图算法和数值算法的 Python 示例。适合对照概念阅读实现，再自行编写测试。',
    url: 'https://github.com/TheAlgorithms/Python', source: 'The Algorithms 官方组织仓库', language: '英语 / Python', kind: '开源代码',
    license: '仓库代码：MIT；不将该许可扩展到仓库链接的外部教材或第三方资源。'
  },
  {
    id: 'ostep', title: 'OSTEP · 操作系统三大主题', category: '系统',
    description: '围绕虚拟化、并发与持久化讲解操作系统。作者提供分章免费在线阅读，可配合实验建立概念图。',
    url: 'https://pages.cs.wisc.edu/~remzi/OSTEP/', source: '威斯康星大学麦迪逊分校 · 作者官网', language: '英语', kind: '免费在线教材（非开源认定）',
    license: '以来源页条款为准。已确认作者提供免费分章阅读，未据此认定教材具有开放再分发许可；实验代码需另查各仓库许可。'
  },
  {
    id: 'xv6', title: 'xv6 · RISC-V 教学操作系统', category: '系统',
    description: '小型 Unix 风格教学系统，可沿进程、页表、系统调用与文件系统阅读源码。适合学过 C 语言后使用。',
    url: 'https://github.com/mit-pdos/xv6-riscv', source: 'MIT PDOS 官方仓库', language: '英语 / C', kind: '开源教学系统',
    license: '本仓库软件及随附文档：MIT 风格许可（见 LICENSE）；外部 xv6 教材与课程材料应另核条款。'
  },
  {
    id: 'kicad', title: 'KiCad · 电路与 PCB 入门', category: '电子',
    description: '官方文档包含原理图、PCB 布局与 SPICE 仿真指南，适合建立从元器件到电路板的学习路线。',
    url: 'https://docs.kicad.org/', source: 'KiCad 官方文档团队', language: '多语言（含中文）', kind: '开放文档与开源工具',
    license: '文档：GPL-3.0-or-later 或 CC BY 3.0-or-later 二选一；软件主体：GPL-3.0-or-later（另有第三方许可）；元件库另为 CC BY-SA 4.0，细节见官方库条款。'
  },
  {
    id: 'freertos', title: 'FreeRTOS · 嵌入式实时内核', category: '电子',
    description: '面向微控制器的实时内核，学习任务调度、队列、信号量与内存管理。适合在掌握 C 与单片机基础后阅读源码。',
    url: 'https://github.com/FreeRTOS/FreeRTOS-Kernel', source: 'FreeRTOS 官方组织仓库', language: '英语 / C', kind: '开源嵌入式内核',
    license: '本内核仓库软件与随附文档：MIT（见 LICENSE.md）；外部文档、演示工程与硬件厂商组件需分别核对许可。'
  },
  {
    id: 'numpy', title: 'NumPy · 数组与线性代数', category: '数值方法',
    description: '科学计算数组基础，覆盖广播、矩阵运算和随机采样。适合梳理数组形状、向量化与线性代数的关系。',
    url: 'https://github.com/numpy/numpy', source: 'NumPy 官方项目仓库', language: '英语 / Python', kind: '开源科学计算库',
    license: '仓库主许可：BSD-3-Clause；捆绑依赖及第三方代码须遵循各自声明。外部文档不自动套用代码许可。'
  },
  {
    id: 'scipy', title: 'SciPy · 数值计算工具箱', category: '数值方法',
    description: '包含优化、积分、插值、信号处理与线性代数算法，适合按“数学问题 → 数值方法 → 工具”组织知识。',
    url: 'https://github.com/scipy/scipy', source: 'SciPy 官方项目仓库', language: '英语 / Python', kind: '开源科学计算库',
    license: '仓库主许可：BSD-3-Clause；第三方组件需另查其许可。外链教程和文档不自动套用代码许可。'
  },
  {
    id: 'sympy', title: 'SymPy · 符号数学与公式推导', category: '数值方法',
    description: '用于符号微积分、代数方程与矩阵运算。适合比较精确符号推导与浮点数值计算的适用场景。',
    url: 'https://github.com/sympy/sympy', source: 'SymPy 官方项目仓库', language: '英语 / Python', kind: '开源符号计算库',
    license: '仓库主体：BSD-3-Clause；LICENSE 另列第三方及部分文件的许可，使用时应逐项核对。外部材料以自身条款为准。'
  }
];

// 与共享 LearningResource 分开保存，避免更改领域类型。
export const RESOURCE_LICENSE_URLS: Record<string, string> = {
  'd2l': 'https://github.com/d2l-ai/d2l-en#license-summary',
  'thinkdsp': 'https://github.com/AllenDowney/ThinkDSP#readme',
  'missing': 'https://missing.csail.mit.edu/license/',
  'mit6006': 'https://ocw.mit.edu/pages/privacy-and-terms-of-use/',
  'cpalg': 'https://github.com/cp-algorithms/cp-algorithms/blob/main/LICENSE',
  'algpython': 'https://github.com/TheAlgorithms/Python/blob/master/LICENSE.md',
  'ostep': 'https://pages.cs.wisc.edu/~remzi/OSTEP/',
  'xv6': 'https://github.com/mit-pdos/xv6-riscv/blob/riscv/LICENSE',
  'kicad': 'https://www.kicad.org/about/licenses/',
  'freertos': 'https://github.com/FreeRTOS/FreeRTOS-Kernel/blob/main/LICENSE.md',
  'numpy': 'https://github.com/numpy/numpy/blob/main/LICENSE.txt',
  'scipy': 'https://github.com/scipy/scipy/blob/main/LICENSE.txt',
  'sympy': 'https://github.com/sympy/sympy/blob/master/LICENSE'
};

export function findOpenResources(query: string, category: string): LearningResource[] {
  const term: string = query.trim().toLowerCase();
  return OPEN_RESOURCES.filter((resource: LearningResource): boolean => {
    const matchesCategory: boolean = category === '全部' || resource.category === category;
    const haystack: string = resource.title + ' ' + resource.description + ' ' + resource.source + ' ' +
      resource.category + ' ' + resource.kind + ' ' + resource.language + ' ' + resource.license;
    return matchesCategory && (term.length === 0 || haystack.toLowerCase().includes(term));
  });
}
