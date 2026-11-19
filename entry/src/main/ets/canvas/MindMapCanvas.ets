import { createDocument, MindMapDocument } from '../domain/MindMap';
import { CanvasNode, layoutMap, MapScene } from './MapLayout';
import { ColorMetrics } from '@kit.ArkUI';
import { EnvironmentCallback, Configuration, AbilityConstant, ConfigurationConstant } from '@kit.AbilityKit';
import common from '@ohos.app.ability.common';

interface CanvasPalette {
  surface: string;
  text: string;
  border: string;
  accent: string;
  onAccent: string;
  soft: string;
  connector: string;
  grid: string;
}

@ComponentV2
export struct MindMapCanvas {
  @Param document: MindMapDocument = createDocument();
  @Param selectedNodeId: string = '';
  @Param fitSignal: number = 0;
  @Param zoomSignal: number = 0;
  @Param appearance: string = 'system';
  @Event onSelect: (id: string) => void = () => {};
  @Event onToggle: (id: string) => void = () => {};
  @Event onZoom: (value: number) => void = () => {};
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private scene: MapScene = { nodes: [], width: 240, height: 120 };
  private nodeIndex: Map<string, CanvasNode> = new Map<string, CanvasNode>();
  private palette: CanvasPalette | null = null;
  private needsFit: boolean = true;
  private applicationContext: common.ApplicationContext | null = null;
  private environmentId: number = -1;
  private paintTimer: number = -1;
  private pinchPanX: number = 0;
  private pinchPanY: number = 0;
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

  private environmentCallback: EnvironmentCallback = {
    onConfigurationUpdated: (_configuration: Configuration): void => { this.refreshAppearance(); },
    onMemoryLevel: (_level: AbilityConstant.MemoryLevel): void => {}
  };

  aboutToAppear(): void {
    if (this.environmentId >= 0) return;
    const context: common.ApplicationContext | undefined = this.getUIContext().getHostContext()?.getApplicationContext();
    if (context !== undefined) {
      this.applicationContext = context;
      this.environmentId = context.on('environment', this.environmentCallback);
    }
    this.refreshAppearance();
  }

  aboutToDisappear(): void {
    if (this.paintTimer >= 0) { clearTimeout(this.paintTimer); this.paintTimer = -1; }
    if (this.applicationContext !== null && this.environmentId >= 0) {
      this.applicationContext.off('environment', this.environmentId).catch((): void => {});
    }
    this.environmentId = -1;
    this.applicationContext = null;
  }

  onWillApplyTheme(_theme: Theme): void { this.refreshAppearance(); }

  @Monitor('appearance')
  refreshAppearance(): void {
    this.palette = null;
    if (this.paintTimer >= 0) clearTimeout(this.paintTimer);
    // Resolve semantic resources after the host has applied the new color mode.
    this.paintTimer = setTimeout((): void => { this.paintTimer = -1; this.palette = null; this.paint(); }, 0);
  }

  private rebuildScene(): void {
    this.scene = layoutMap(this.document);
    this.nodeIndex = new Map<string, CanvasNode>();
    this.scene.nodes.forEach((node: CanvasNode): void => { this.nodeIndex.set(node.id, node); });
  }

  @Monitor('document')
  refreshDocument(): void {
    this.rebuildScene();
    if (this.currentDocumentId !== this.document.documentId) { this.needsFit = true; this.fit(); }
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
    this.needsFit = false;
    this.onZoom(Math.round(this.zoom * 1000) / 10);
  }

  private updateViewport(width: number, height: number): void {
    if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) return;
    if (width === this.viewportWidth && height === this.viewportHeight) return;
    const oldWidth: number = this.viewportWidth;
    const oldHeight: number = this.viewportHeight;
    this.viewportWidth = width;
    this.viewportHeight = height;
    if (!this.ready) return;
    if (this.needsFit || oldWidth <= 0 || oldHeight <= 0) this.fit();
    else {
      this.panX += (width - oldWidth) / 2;
      this.panY += (height - oldHeight) / 2;
    }
    this.paint();
  }

  private beginPan(): void { this.startX = this.panX; this.startY = this.panY; }
  private updatePan(x: number, y: number): void { this.panX = this.startX + x; this.panY = this.startY + y; this.paint(); }
  private cancelPan(): void { this.panX = this.startX; this.panY = this.startY; this.paint(); }
  private beginPinch(): void { this.startZoom = this.zoom; this.pinchPanX = this.panX; this.pinchPanY = this.panY; }
  private cancelPinch(): void {
    this.zoom = this.startZoom; this.panX = this.pinchPanX; this.panY = this.pinchPanY;
    this.onZoom(Math.round(this.zoom * 1000) / 10); this.paint();
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
      const rgba: ColorMetrics = ColorMetrics.resourceColor(resource);
      if (rgba.alpha > 0 && rgba.red + rgba.green + rgba.blue > 0) {
        return '#' + ((rgba.red << 16) | (rgba.green << 8) | rgba.blue).toString(16).padStart(6, '0');
      }
    } catch (_) { /* The drawing context can attach before the resource theme. */ }
    try {
      const value: number | undefined = this.getUIContext().getHostContext()?.resourceManager.getColorSync(resource);
      if (value !== undefined && Number.isFinite(value) && (value & 0xFFFFFF) !== 0) {
        return '#' + (value & 0xFFFFFF).toString(16).padStart(6, '0');
      }
    } catch (_) {}
    return fallback;
  }

  private paint(): void {
    if (!this.ready) { return; }
    const ctx: CanvasRenderingContext2D = this.context;
    const palette: CanvasPalette = this.getPalette();
    ctx.clearRect(0, 0, this.viewportWidth, this.viewportHeight);
    ctx.save();
    ctx.fillStyle = palette.grid;
    const dotX: number = ((this.panX % 24) + 24) % 24;
    const dotY: number = ((this.panY % 24) + 24) % 24;
    for (let y: number = dotY; y < this.viewportHeight; y += 24) {
      for (let x: number = dotX; x < this.viewportWidth; x += 24) ctx.fillRect(x, y, 1.2, 1.2);
    }
    ctx.translate(this.panX, this.panY);
    ctx.scale(this.zoom, this.zoom);
    ctx.lineWidth = 2;
    this.scene.nodes.forEach((node: CanvasNode) => {
      const parent: CanvasNode | undefined = this.nodeIndex.get(node.parentId);
      if (!parent) { return; }
      ctx.strokeStyle = palette.connector;
      ctx.beginPath();
      if (this.document.layout === 'down') {
        const x: number = parent.x + parent.width / 2;
        const y: number = parent.y + parent.height;
        ctx.moveTo(x, y);
        ctx.bezierCurveTo(x, y + 20, node.x + node.width / 2, node.y - 20, node.x + node.width / 2, node.y);
      } else {
        const x: number = parent.x + parent.width;
        const y: number = parent.y + parent.height / 2;
        ctx.moveTo(x, y);
        ctx.bezierCurveTo(x + 15, y, node.x - 15, node.y + node.height / 2, node.x, node.y + node.height / 2);
      }
      ctx.stroke();
    });
    this.scene.nodes.forEach((node: CanvasNode) => {
      const selected: boolean = node.id === this.selectedNodeId;
      ctx.fillStyle = node.depth === 0 ? palette.accent : selected ? palette.soft : palette.surface;
      ctx.strokeStyle = selected ? (node.depth === 0 ? palette.onAccent : palette.accent) : palette.border;
      ctx.lineWidth = selected ? 2.5 : 1;
      ctx.beginPath();
      ctx.roundRect(node.x, node.y, node.width, node.height, 14);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = node.depth === 0 ? palette.onAccent : palette.text;
      ctx.font = node.depth === 0 ? 'bold 15vp sans-serif' : '15vp sans-serif';
      ctx.textBaseline = 'middle';
      const firstLine: number = node.y + (node.height - (node.lines.length - 1) * 22) / 2;
      node.lines.forEach((line: string, index: number) => ctx.fillText(line, node.x + 15, firstLine + index * 22, node.width - 30));
      if (node.childCount > 0) {
        ctx.fillStyle = palette.accent;
        ctx.beginPath();
        ctx.arc(node.x + node.width, node.y + node.height / 2, 11, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = palette.onAccent;
        ctx.font = '14vp sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(node.collapsed ? '+' : '−', node.x + node.width, node.y + node.height / 2);
        ctx.textAlign = 'left';
      }
    });
    ctx.restore();
  }

  private getPalette(): CanvasPalette {
    if (this.palette !== null) return this.palette;
    const host = this.getUIContext().getHostContext() as common.UIAbilityContext | undefined;
    const dark: boolean = this.appearance === 'dark' || (this.appearance === 'system' &&
      host?.config?.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    this.palette = {
      surface: this.color($r('app.color.fs_surface'), dark ? '#1C1D22' : '#FFFFFF'),
      text: this.color($r('app.color.fs_text'), dark ? '#F5F5F7' : '#1D1D1F'),
      border: this.color($r('app.color.fs_border'), dark ? '#393B44' : '#DADAE2'),
      accent: this.color($r('app.color.fs_accent'), dark ? '#B1AEFF' : '#5354C7'),
      onAccent: this.color($r('app.color.fs_on_accent'), dark ? '#171630' : '#FFFFFF'),
      soft: this.color($r('app.color.fs_soft'), dark ? '#313046' : '#ECECFA'),
      connector: this.color($r('app.color.fs_connector'), '#81849B'),
      grid: this.color($r('app.color.fs_grid'), dark ? '#2B2D36' : '#DEDFE7')
    };
    return this.palette;
  }

  private selectAt(x: number, y: number): void {
    const mapX: number = (x - this.panX) / this.zoom;
    const mapY: number = (y - this.panY) / this.zoom;
    const hit: CanvasNode | undefined = this.scene.nodes.find((node: CanvasNode) => mapX >= node.x - 8 &&
      mapX <= node.x + node.width + 12 && mapY >= node.y - 8 && mapY <= node.y + node.height + 8);
    if (!hit) { return; }
    this.onSelect(hit.id);
    const dx: number = mapX - hit.x - hit.width;
    const dy: number = mapY - hit.y - hit.height / 2;
    if (hit.childCount > 0 && dx * dx + dy * dy <= 12 * 12) { this.onToggle(hit.id); }
  }

  build() {
    Canvas(this.context)
      .width('100%').height('100%')
      .backgroundColor($r('app.color.fs_bg'))
      .accessibilityText('思维导图画布，单指拖动平移，双指缩放，点击节点选中。可通过节点面板编辑。')
      .onReady(() => {
        this.ready = true;
        this.rebuildScene();
        this.currentDocumentId = this.document.documentId;
        this.updateViewport(this.context.width, this.context.height);
        if (this.needsFit) this.fit();
        this.paint();
      })
      .onAreaChange((_old: Area, area: Area) => {
        this.updateViewport(Number(area.width), Number(area.height));
      })
      .gesture(GestureGroup(GestureMode.Exclusive,
        PinchGesture().onActionStart(() => { this.beginPinch(); })
          .onActionUpdate((event: GestureEvent) => { this.setZoom(this.startZoom * event.scale); })
          .onActionCancel(() => { this.cancelPinch(); }),
        PanGesture({ fingers: 1, distance: 5 }).onActionStart(() => { this.beginPan(); })
          .onActionUpdate((event: GestureEvent) => { this.updatePan(event.offsetX, event.offsetY); })
          .onActionCancel(() => { this.cancelPan(); }),
        TapGesture().onAction((event: GestureEvent) => {
          if (event.fingerList.length > 0) { this.selectAt(event.fingerList[0].localX, event.fingerList[0].localY); }
        })
      ))
  }
}
