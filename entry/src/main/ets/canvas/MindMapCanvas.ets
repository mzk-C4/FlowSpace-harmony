import { createDocument, MindMapDocument } from '../domain/MindMap';
import { CanvasNode, layoutMap, MapScene } from './MapLayout';

@ComponentV2
export struct MindMapCanvas {
  @Param document: MindMapDocument = createDocument();
  @Param selectedNodeId: string = '';
  @Param fitSignal: number = 0;
  @Param zoomSignal: number = 0;
  @Event onSelect: (id: string) => void = () => {};
  @Event onZoom: (value: number) => void = () => {};
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private scene: MapScene = { nodes: [], width: 240, height: 120 };
  private viewportWidth: number = 0;
  private viewportHeight: number = 0;
  private zoom: number = 1;
  private panX: number = 0;
  private panY: number = 0;
  private startX: number = 0;
  private startY: number = 0;
  private startZoom: number = 1;
  private ready: boolean = false;
  private currentDocumentId: string = '';

  @Monitor('document')
  refreshDocument(): void {
    this.scene = layoutMap(this.document);
    if (this.currentDocumentId !== this.document.documentId) { this.fit(); }
    this.currentDocumentId = this.document.documentId;
    this.paint();
  }

  @Monitor('selectedNodeId')
  refreshSelection(): void { this.paint(); }

  @Monitor('fitSignal')
  requestFit(): void { this.fit(); this.paint(); }

  @Monitor('zoomSignal')
  requestZoom(): void {
    this.setZoom(this.zoom * (this.zoomSignal > this.previousZoomSignal ? 1.2 : 1 / 1.2));
    this.previousZoomSignal = this.zoomSignal;
  }
  private previousZoomSignal: number = 0;

  private fit(): void {
    if (this.viewportWidth <= 0 || this.viewportHeight <= 0) { return; }
    this.zoom = Math.max(0.000001, Math.min(1.25, Math.min(this.viewportWidth / this.scene.width,
      this.viewportHeight / this.scene.height) * 0.92));
    this.panX = (this.viewportWidth - this.scene.width * this.zoom) / 2;
    this.panY = (this.viewportHeight - this.scene.height * this.zoom) / 2;
    this.onZoom(Math.round(this.zoom * 1000) / 10);
  }

  private setZoom(value: number): void {
    const next: number = Math.max(0.000001, Math.min(3, value));
    const ratio: number = next / this.zoom;
    this.panX = this.viewportWidth / 2 - (this.viewportWidth / 2 - this.panX) * ratio;
    this.panY = this.viewportHeight / 2 - (this.viewportHeight / 2 - this.panY) * ratio;
    this.zoom = next;
    this.onZoom(Math.round(next * 1000) / 10);
    this.paint();
  }

  private color(resource: Resource, fallback: string): string {
    try {
      const value: number | undefined = this.getUIContext().getHostContext()?.resourceManager.getColorSync(resource);
      if (value !== undefined) { return '#' + (value & 0xFFFFFF).toString(16).padStart(6, '0'); }
    } catch (_) { /* Resource unavailable only before host attachment. */ }
    return fallback;
  }

  private paint(): void {
    if (!this.ready) { return; }
    const ctx: CanvasRenderingContext2D = this.context;
    const surface: string = this.color($r('app.color.fs_surface'), '#FFFFFF');
    const text: string = this.color($r('app.color.fs_text'), '#252635');
    const border: string = this.color($r('app.color.fs_border'), '#DADAE6');
    const accent: string = this.color($r('app.color.fs_accent'), '#635BDE');
    ctx.clearRect(0, 0, this.viewportWidth, this.viewportHeight);
    ctx.save();
    ctx.translate(this.panX, this.panY);
    ctx.scale(this.zoom, this.zoom);
    ctx.lineWidth = 2;
    this.scene.nodes.forEach((node: CanvasNode) => {
      const parent: CanvasNode | undefined = this.scene.nodes.find((item: CanvasNode) => item.id === node.parentId);
      if (!parent) { return; }
      ctx.strokeStyle = border;
      ctx.beginPath();
      if (this.document.layout === 'down') {
        const x: number = parent.x + parent.width / 2;
        const y: number = parent.y + parent.height;
        ctx.moveTo(x, y);
        ctx.bezierCurveTo(x, y + 36, node.x + 90, node.y - 36, node.x + 90, node.y);
      } else {
        const x: number = parent.x + parent.width;
        const y: number = parent.y + parent.height / 2;
        ctx.moveTo(x, y);
        ctx.bezierCurveTo(x + 36, y, node.x - 36, node.y + node.height / 2, node.x, node.y + node.height / 2);
      }
      ctx.stroke();
    });
    this.scene.nodes.forEach((node: CanvasNode) => {
      const selected: boolean = node.id === this.selectedNodeId;
      ctx.fillStyle = node.depth === 0 ? accent : surface;
      ctx.strokeStyle = selected ? accent : border;
      ctx.lineWidth = selected ? 3 : 1;
      ctx.beginPath();
      ctx.roundRect(node.x, node.y, node.width, node.height, 14);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = node.depth === 0 ? '#FFFFFF' : text;
      ctx.font = '15px HarmonyOS Sans';
      ctx.textBaseline = 'top';
      node.lines.forEach((line: string, index: number) => ctx.fillText(line, node.x + 15, node.y + 13 + index * 22, 150));
      if (node.childCount > 0) {
        ctx.fillStyle = accent;
        ctx.beginPath();
        ctx.arc(node.x + node.width, node.y + node.height / 2, 11, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = '#FFFFFF';
        ctx.font = '12px HarmonyOS Sans';
        ctx.fillText(node.collapsed ? '+' : '−', node.x + node.width - 4, node.y + node.height / 2 - 7);
      }
    });
    ctx.restore();
  }

  private selectAt(x: number, y: number): void {
    const mapX: number = (x - this.panX) / this.zoom;
    const mapY: number = (y - this.panY) / this.zoom;
    const hit: CanvasNode | undefined = this.scene.nodes.find((node: CanvasNode) => mapX >= node.x - 8 &&
      mapX <= node.x + node.width + 12 && mapY >= node.y - 8 && mapY <= node.y + node.height + 8);
    if (hit) { this.onSelect(hit.id); }
  }

  build() {
    Canvas(this.context)
      .width('100%').height('100%')
      .backgroundColor($r('app.color.fs_bg'))
      .accessibilityText('思维导图画布，单指拖动平移，双指缩放，点击节点选中。可通过节点面板编辑。')
      .onReady(() => {
        this.ready = true;
        this.scene = layoutMap(this.document);
        this.viewportWidth = this.context.width;
        this.viewportHeight = this.context.height;
        this.currentDocumentId = this.document.documentId;
        this.fit(); this.paint();
      })
      .onAreaChange((_old: Area, area: Area) => {
        this.viewportWidth = Number(area.width); this.viewportHeight = Number(area.height);
        this.fit(); this.paint();
      })
      .gesture(GestureGroup(GestureMode.Exclusive,
        PinchGesture().onActionStart(() => { this.startZoom = this.zoom; })
          .onActionUpdate((event: GestureEvent) => { this.setZoom(this.startZoom * event.scale); }),
        PanGesture({ fingers: 1, distance: 5 }).onActionStart(() => { this.startX = this.panX; this.startY = this.panY; })
          .onActionUpdate((event: GestureEvent) => {
            this.panX = this.startX + event.offsetX; this.panY = this.startY + event.offsetY; this.paint();
          }),
        TapGesture().onAction((event: GestureEvent) => {
          if (event.fingerList.length > 0) { this.selectAt(event.fingerList[0].localX, event.fingerList[0].localY); }
        })
      ))
  }
}
