# 原生Canvas计算与方法验证

新增 `tools/tests/canvas-layout.mjs`。测试直接转译当前 `MapLayout.ets` 与 `MindMapCanvas.ets` 实现；仅去除ArkUI装饰器和声明式build区，替换两个原生上下文构造器。真实fit、setZoom、selectAt、refreshDocument方法保持原样；ready=false时实际paint自行提前返回。此验证不执行Canvas绘图、不模拟手势系统，也不是手机帧率或性能验收。

## 覆盖

- 200/500节点、right/down布局：所有节点矩形两两不相交，图边界覆盖全部矩形；冻结输入后计算，不修改领域数据。
- 长中文节点逐行完整保留、节点高度容纳所有行；折叠后隐藏相应子树，childCount保留。
- emoji不能把UTF16高低代理项拆到不同绘制行。
- 320/360/390/480vp手机视口，每个尺寸分别检查200/500节点、平衡/星型、right/down实际fit后的所有矩形都在视口内。
- 实际selectAt在fit、平移、缩放后命中正确节点；空白位置不错误选中。
- 实际setZoom保持视口中心对应的图坐标不变，并发出当前显示百分比。
- 同一文档刷新保留平移缩放，切换文档重新fit。
- 最大合法500节点、每节点500中文字符的星型图紧凑视口边界。

最终执行 `node --test tools/tests/canvas-layout.mjs`：15项全部通过。首次发现并报告主线程的两处边界均已修复并由实际源码复测：right布局高度约575k的合法长标签星型图在320×280视口需要zoom约0.00045，旧0.001最小值造成裁切；旧charAt逐UTF16码元会把emoji代理项拆到不同绘制行。主线程完成Canvas修复，本分任务仅增加测试与记录。

初次Node进程内四次布局计算耗时约0.28–1.96ms；此数字仅是本机Node纯布局调用用时，不包含ArkTS、设备、原生Canvas绘制、手势或字体，不作为手机FPS或运行性能结论。
