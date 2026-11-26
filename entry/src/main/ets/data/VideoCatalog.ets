import { LearningResource } from '../domain/MindMap';

// Official course/video pages verified 2026-11-03 and re-checked 2026-11-24 (all eight returned HTTP 200).
// These are official links, not bundled videos.
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

// 首页视频筛选使用的固定分类顺序，第一个为“全部”。
export const VIDEO_CATEGORIES: string[] = ['全部', '数学基础', '算法', '电路', '信号', '控制'];

export function findVideos(category: string): LearningResource[] {
  return category === '全部' ? VIDEO_RESOURCES.slice() :
    VIDEO_RESOURCES.filter((resource: LearningResource): boolean => resource.category === category);
}

// 与共享 LearningResource 分开保存，避免更改领域类型。videoId 与 LearningResource.id 一一对应。
// 核验日期 2026-11-24（Asia/Shanghai）：八条官方课程页均返回 HTTP 200，主讲与课程信息按官方页面复核；
// HTTP 可达不等于实体手机可播放，也未据此认定视频可以下载或再分发。
export interface VideoVerification {
  videoId: string;
  provider: string;
  instructor: string;
  access: string;
  fitFor: string;
  verifiedAt: string;
}

export const VIDEO_VERIFICATION: Record<string, VideoVerification> = {
  'video-mit-1806': {
    videoId: 'video-mit-1806',
    provider: 'MIT OpenCourseWare · 18.06 Linear Algebra',
    instructor: 'Prof. Gilbert Strang',
    access: '课程页免费公开、无需登录；英语授课。视频在官方视频目录内嵌播放，可用性取决于原站与所在网络。',
    fitFor: '配合手工推导建立矩阵、向量空间、特征值与 SVD 的直觉，再进入信号与系统、控制等课程。',
    verifiedAt: '2026-11-24'
  },
  'video-mit-1801': {
    videoId: 'video-mit-1801',
    provider: 'MIT OpenCourseWare · 18.01SC Single Variable Calculus',
    instructor: 'Prof. David Jerison',
    access: '课程页免费公开、无需登录；英语授课。讲课与解题视频分布在课程单元页内，可用性取决于原站与所在网络。',
    fitFor: '补齐微积分前置：极限、微分、积分与级数，为微分方程和信号类课程打底。',
    verifiedAt: '2026-11-24'
  },
  'video-mit-1803': {
    videoId: 'video-mit-1803',
    provider: 'MIT OpenCourseWare · 18.03SC Differential Equations',
    instructor: 'Prof. Arthur Mattuck（讲课视频）；课程讲师团队另含 Haynes Miller、Jeremy Orloff、John Lewis',
    access: '课程页免费公开、无需登录；英语授课。讲课视频与解题视频分列各单元，可用性取决于原站与所在网络。',
    fitFor: '把一阶/二阶方程、傅里叶与拉普拉斯变换对应到电路、振动与控制问题。',
    verifiedAt: '2026-11-24'
  },
  'video-mit-6006': {
    videoId: 'video-mit-6006',
    provider: 'MIT OpenCourseWare · 6.006 Introduction to Algorithms',
    instructor: 'Prof. Erik Demaine、Prof. Srini Devadas',
    access: '课程页免费公开、无需登录；英语授课。讲课视频在官方视频目录内嵌播放，可用性取决于原站与所在网络。',
    fitFor: '配合刷题梳理排序、哈希、树、图与动态规划的时间和空间取舍。',
    verifiedAt: '2026-11-24'
  },
  'video-mit-6042': {
    videoId: 'video-mit-6042',
    provider: 'MIT OpenCourseWare · 6.042J Mathematics for Computer Science',
    instructor: 'Prof. Tom Leighton、Dr. Marten van Dijk',
    access: '课程页免费公开、无需登录；英语授课。讲课视频在官方视频目录内嵌播放，可用性取决于原站与所在网络。',
    fitFor: '补齐离散数学与证明方法，为算法正确性、图论和概率分析提供基础。',
    verifiedAt: '2026-11-24'
  },
  'video-mit-6002': {
    videoId: 'video-mit-6002',
    provider: 'MIT OpenCourseWare · 6.002 Circuits and Electronics',
    instructor: 'Prof. Anant Agarwal',
    access: '课程页免费公开、无需登录；英语授课。讲课视频在官方视频目录内嵌播放，可用性取决于原站与所在网络。',
    fitFor: '从电阻网络到晶体管与运放建立电路直觉，再进入模拟电子与嵌入式。',
    verifiedAt: '2026-11-24'
  },
  'video-mit-signals': {
    videoId: 'video-mit-signals',
    provider: 'MIT OpenCourseWare · RES.6-007 Signals and Systems',
    instructor: 'Prof. Alan V. Oppenheim',
    access: '课程页免费公开、无需登录；英语授课。讲课视频在官方视频目录内嵌播放，可用性取决于原站与所在网络。',
    fitFor: '把卷积、傅里叶、采样与滤波对照《信号与系统》教材章节复习。',
    verifiedAt: '2026-11-24'
  },
  'video-mit-feedback': {
    videoId: 'video-mit-feedback',
    provider: 'MIT OpenCourseWare · RES.6-010 Electronic Feedback Systems',
    instructor: 'Prof. James Roberge（1985 年授课录像，共 20 讲）',
    access: '课程页免费公开、无需登录；英语授课。录像另在 Teaching Excellence at MIT 站点提供，可用性取决于原站与所在网络。',
    fitFor: '在学过信号与系统后，用经典反馈案例理解稳定性、根轨迹、频率响应与补偿。',
    verifiedAt: '2026-11-24'
  }
};
