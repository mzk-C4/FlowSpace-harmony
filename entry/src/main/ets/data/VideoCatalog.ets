import { LearningResource } from '../domain/MindMap';

// Official course/video pages verified 2026-11-03. These are links, not bundled videos.
const OCW_LICENSE: string = 'CC BY-NC-SA 4.0（另有标注的第三方材料除外）；免费公开学习，播放取决于网络与原站条件';

export const VIDEO_RESOURCES: LearningResource[] = [
  {
    id: 'video-mit-1806', title: '线性代数 · 从方程到向量空间', category: '数学基础',
    description: 'Gilbert Strang 主讲。用几何直觉理解矩阵、线性空间、特征值与奇异值分解。',
    url: 'https://ocw.mit.edu/courses/18-06-linear-algebra-spring-2010/video_galleries/video-lectures/',
    source: 'MIT OpenCourseWare · 18.06', license: OCW_LICENSE, language: '英语', kind: '课程视频集合'
  },
  {
    id: 'video-mit-1801', title: '单变量微积分 · 自学课程', category: '数学基础',
    description: 'David Jerison 主讲。按微分、积分、应用与级数组织学习，课程单元包含讲课和解题视频。',
    url: 'https://ocw.mit.edu/courses/18-01sc-single-variable-calculus-fall-2010/',
    source: 'MIT OpenCourseWare · 18.01SC', license: OCW_LICENSE, language: '英语', kind: '课程视频集合'
  },
  {
    id: 'video-mit-1803', title: '微分方程 · 工程建模基础', category: '数学基础',
    description: '从一阶方程、振动到拉普拉斯变换与方程组；课程单元配有讲解与解题视频。',
    url: 'https://ocw.mit.edu/courses/18-03sc-differential-equations-fall-2011/',
    source: 'MIT OpenCourseWare · 18.03SC', license: OCW_LICENSE, language: '英语', kind: '课程视频集合'
  },
  {
    id: 'video-mit-6006', title: '算法导论 · 数据结构与复杂度', category: '算法',
    description: 'Erik Demaine、Srini Devadas 主讲。学习排序、搜索、图算法与动态规划的设计和分析。',
    url: 'https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-fall-2011/video_galleries/lecture-videos/',
    source: 'MIT OpenCourseWare · 6.006', license: OCW_LICENSE, language: '英语', kind: '课程视频集合'
  },
  {
    id: 'video-mit-6042', title: '计算机数学 · 证明与离散结构', category: '算法',
    description: 'Tom Leighton、Marten van Dijk 主讲。连接逻辑证明、图论、计数与离散概率。',
    url: 'https://ocw.mit.edu/courses/6-042j-mathematics-for-computer-science-fall-2010/video_galleries/video-lectures/',
    source: 'MIT OpenCourseWare · 6.042J', license: OCW_LICENSE, language: '英语', kind: '课程视频集合'
  },
  {
    id: 'video-mit-6002', title: '电路与电子学 · 建立电路直觉', category: '电路',
    description: 'Anant Agarwal 主讲。覆盖电阻网络、晶体管、放大器、储能元件与电路的时频域分析。',
    url: 'https://ocw.mit.edu/courses/6-002-circuits-and-electronics-spring-2007/video_galleries/video-lectures/',
    source: 'MIT OpenCourseWare · 6.002', license: OCW_LICENSE, language: '英语', kind: '课程视频集合'
  },
  {
    id: 'video-mit-signals', title: '信号与系统 · 时域与频域', category: '信号',
    description: 'Alan Oppenheim 主讲。理解连续与离散信号、卷积、傅里叶变换、采样和滤波。',
    url: 'https://ocw.mit.edu/courses/res-6-007-signals-and-systems-spring-2011/video_galleries/video-lectures/',
    source: 'MIT OpenCourseWare · RES.6-007', license: OCW_LICENSE, language: '英语', kind: '课程视频集合'
  },
  {
    id: 'video-mit-feedback', title: '电子反馈系统 · 经典控制入门', category: '控制',
    description: 'James Roberge 主讲。围绕反馈、稳定性、根轨迹、频率响应与补偿建立知识体系。',
    url: 'https://ocw.mit.edu/courses/res-6-010-electronic-feedback-systems-spring-2013/video_galleries/course-videos/',
    source: 'MIT OpenCourseWare · RES.6-010', license: OCW_LICENSE, language: '英语', kind: '课程视频集合'
  }
];
