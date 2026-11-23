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
  dark: boolean;
}

interface Projection {
  cx: number;
  cy: number;
}

interface ProjectedNode {
  node: CanvasNode;
  x: number;
  y: number;
  width: number;
  height: number;
  scale: number;
  z: number;
}

@ComponentV2
export struct MindMapCanvas {
  @Param document: MindMapDocument = createDocument();
  @Param selectedNodeId: string = '';
  @Param fitSignal: number = 0;
  @Param zoomSignal: number = 0;
  @Param appearance: string = 'system';
  @Param viewMode: string = '2d';
  @Event onSelect: (id: string) => void = () => {};
  @Event onToggle: (id: string) => void = () => {};
  @Event onZoom: (value: number) => void = () => {};
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private scene: MapScene = { nodes: [], width: 240, height: 120 };
  private nodeIndex: Map<string, CanvasNode> = new Map<string, CanvasNode>();
  private selectedPath: Set<string> = new Set<string>();
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
    this.rebuildSelectionPath();
  }

  // Selection feedback covers the whole branch, not a single box: root → selected node.
  private rebuildSelectionPath(): void {
    const path: Set<string> = new Set<string>();
    let current: CanvasNode | undefined = this.nodeIndex.get(this.selectedNodeId);
    for (let depth: number = 0; current !== undefined && depth < 9; depth++) {
      path.add(current.id);
      if (current.parentId === '') { break; }
      current = this.nodeIndex.get(current.parentId);
    }
    this.selectedPath = path;
  }

  // A layered camera: deeper levels shrink and cascade down-right while the
  // tree keeps its 2D spacing, so cards read as stacked layers without overlap.
  private projection(): Projection {
    return { cx: this.scene.width / 2, cy: this.scene.height / 2 };
  }

  private projectNode(node: CanvasNode, projection: Projection = this.projection()): ProjectedNode {
    const depth: number = node.depth;
    const scale: number = Math.max(0.5, 1 - depth * 0.06);
    // Positions keep the 2D tree spacing; only card size and a small cascade
    // change with depth, so connectors never double back across a level.
    const x: number = (node.x + node.width / 2 - projection.cx) + depth * 20;
    const y: number = (node.y + node.height / 2 - projection.cy) + depth * 24;
    return { node: node, x: x, y: y, width: node.width * scale,
      height: node.height * scale, scale: scale, z: depth };
  }

  private projectedBounds(): { minX: number; minY: number; width: number; height: number } {
    const projection: Projection = this.projection();
    let minX: number = Infinity;
    let minY: number = Infinity;
    let maxX: number = -Infinity;
    let maxY: number = -Infinity;
    this.scene.nodes.forEach((node: CanvasNode): void => {
      const item: ProjectedNode = this.projectNode(node, projection);
      minX = Math.min(minX, item.x - item.width / 2);
      minY = Math.min(minY, item.y - item.height / 2);
      maxX = Math.max(maxX, item.x + item.width / 2);
      maxY = Math.max(maxY, item.y + item.height / 2);
    });
    if (!Number.isFinite(minX) || !Number.isFinite(minY)) {
      return { minX: 0, minY: 0, width: Math.max(1, this.scene.width), height: Math.max(1, this.scene.height) };
    }
    return { minX: minX, minY: minY, width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) };
  }

  private shade(hex: string, factor: number): string {
    if (!/^#[0-9a-fA-F]{6}$/.test(hex)) { return hex; }
    const value: number = parseInt(hex.slice(1), 16);
    const red: number = Math.round(((value >> 16) & 255) * factor);
    const green: number = Math.round(((value >> 8) & 255) * factor);
    const blue: number = Math.round((value & 255) * factor);
    return '#' + ((red << 16) | (green << 8) | blue).toString(16).padStart(6, '0');
  }

  @Monitor('document')
  refreshDocument(): void {
    this.rebuildScene();
    if (this.currentDocumentId !== this.document.documentId) { this.needsFit = true; this.fit(); }
    this.currentDocumentId = this.document.documentId;
    this.paint();
  }

  @Monitor('selectedNodeId')
  refreshSelection(): void { this.rebuildSelectionPath(); this.paint(); }

  @Monitor('viewMode')
  refreshViewMode(): void {
    this.needsFit = true;
    this.fit();
    this.paint();
  }

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
    const bounds: { minX: number; minY: number; width: number; height: number } = this.viewMode === '3d' ?
      this.projectedBounds() : { minX: 0, minY: 0, width: this.scene.width, height: this.scene.height };
    this.zoom = Math.max(0.000001, Math.min(1.25, Math.min(this.viewportWidth / bounds.width,
      this.viewportHeight / bounds.height) * 0.92));
    this.panX = (this.viewportWidth - bounds.width * this.zoom) / 2 - bounds.minX * this.zoom;
    this.panY = (this.viewportHeight - bounds.height * this.zoom) / 2 - bounds.minY * this.zoom;
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
    if (this.viewMode === '3d') { this.paint3D(ctx, palette); } else { this.paint2D(ctx, palette); }
    ctx.restore();
  }

  private paint2D(ctx: CanvasRenderingContext2D, palette: CanvasPalette): void {
    this.scene.nodes.forEach((node: CanvasNode) => {
      const parent: CanvasNode | undefined = this.nodeIndex.get(node.parentId);
      if (!parent) { return; }
      const onBranch: boolean = this.selectedPath.has(node.id) && this.selectedPath.has(parent.id);
      ctx.strokeStyle = onBranch ? palette.accent : palette.connector;
      ctx.lineWidth = onBranch ? 2.6 : 1.8;
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
      const onBranch: boolean = this.selectedPath.has(node.id);
      const isRoot: boolean = node.depth === 0;
      ctx.fillStyle = isRoot ? palette.accent : selected ? palette.soft : palette.surface;
      if (isRoot) {
        ctx.strokeStyle = selected ? palette.onAccent : palette.accent;
        ctx.lineWidth = selected ? 2.5 : 1;
      } else if (selected) {
        ctx.strokeStyle = palette.accent;
        ctx.lineWidth = 2.5;
      } else if (onBranch) {
        ctx.strokeStyle = palette.accent;
        ctx.lineWidth = 1.8;
      } else if (node.depth === 1) {
        // First-level branches carry a light accent edge so depth reads before text does.
        ctx.strokeStyle = palette.accent;
        ctx.lineWidth = 1.2;
      } else {
        ctx.strokeStyle = palette.border;
        ctx.lineWidth = 1;
      }
      ctx.beginPath();
      ctx.roundRect(node.x, node.y, node.width, node.height, 14);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = isRoot ? palette.onAccent : palette.text;
      ctx.font = isRoot ? 'bold 15vp sans-serif' : '15vp sans-serif';
      ctx.textBaseline = 'middle';
      const firstLine: number = node.y + (node.height - (node.lines.length - 1) * 22) / 2;
      node.lines.forEach((line: string, index: number) => ctx.fillText(line, node.x + 15, firstLine + index * 22, node.width - 30));
      if (node.childCount > 0) {
        ctx.fillStyle = palette.accent;
        ctx.beginPath();
        ctx.arc(node.x + node.width, node.y + node.height / 2, 11, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = palette.onAccent;
        ctx.font = node.collapsed ? '10vp sans-serif' : '14vp sans-serif';
        ctx.textAlign = 'center';
        const badge: string = node.collapsed ? (node.hiddenCount > 99 ? '+99' : '+' + (node.hiddenCount || 0)) : '−';
        ctx.fillText(badge, node.x + node.width, node.y + node.height / 2);
        ctx.textAlign = 'left';
      }
    });
  }

  private paint3D(ctx: CanvasRenderingContext2D, palette: CanvasPalette): void {
    const projection: Projection = this.projection();
    const projected: ProjectedNode[] = this.scene.nodes.map((node: CanvasNode) => this.projectNode(node, projection));
    projected.forEach((item: ProjectedNode) => {
      const parent: CanvasNode | undefined = this.nodeIndex.get(item.node.parentId);
      if (!parent) { return; }
      const parentProjected: ProjectedNode = this.projectNode(parent, projection);
      const onBranch: boolean = this.selectedPath.has(item.node.id) && this.selectedPath.has(parent.id);
      const averageScale: number = (item.scale + parentProjected.scale) / 2;
      ctx.strokeStyle = onBranch ? palette.accent : palette.connector;
      ctx.lineWidth = (onBranch ? 2.6 : 1.8) * averageScale;
      ctx.beginPath();
      if (this.document.layout === 'down') {
        const startX: number = parentProjected.x;
        const startY: number = parentProjected.y + parentProjected.height / 2;
        const endX: number = item.x;
        const endY: number = item.y - item.height / 2;
        const middle: number = (startY + endY) / 2;
        ctx.moveTo(startX, startY);
        ctx.bezierCurveTo(startX, middle, endX, middle, endX, endY);
      } else {
        const startX: number = parentProjected.x + parentProjected.width / 2;
        const startY: number = parentProjected.y;
        const endX: number = item.x - item.width / 2;
        const endY: number = item.y;
        const middle: number = (startX + endX) / 2;
        ctx.moveTo(startX, startY);
        ctx.bezierCurveTo(middle, startY, middle, endY, endX, endY);
      }
      ctx.stroke();
    });
    const ordered: ProjectedNode[] = projected.slice().sort((a: ProjectedNode, b: ProjectedNode) => b.z - a.z);
    ordered.forEach((item: ProjectedNode) => this.paintCard3D(ctx, palette, item));
    const selected: ProjectedNode | undefined = ordered.find((item: ProjectedNode) => item.node.id === this.selectedNodeId);
    // Repaint only the selected top face so its shadow does not smear over nearer cards.
    if (selected !== undefined) { this.paintCard3D(ctx, palette, selected, false); }
  }

  private paintCard3D(ctx: CanvasRenderingContext2D, palette: CanvasPalette, item: ProjectedNode,
    extruded: boolean = true): void {
    const node: CanvasNode = item.node;
    const scale: number = item.scale;
    const x: number = item.x - item.width / 2;
    const y: number = item.y - item.height / 2;
    const radius: number = 14 * scale;
    const lift: number = 10 * scale;
    const selected: boolean = node.id === this.selectedNodeId;
    const onBranch: boolean = this.selectedPath.has(node.id);
    const isRoot: boolean = node.depth === 0;
    if (extruded) {
      ctx.fillStyle = palette.dark ? 'rgba(0, 0, 0, 0.42)' : 'rgba(16, 17, 20, 0.14)';
      ctx.beginPath();
      ctx.roundRect(x + 5 * scale, y + lift + 5 * scale, item.width, item.height, radius);
      ctx.fill();
      const sideFactor: number = isRoot ? 0.72 : palette.dark ? 1.4 : 0.62;
      ctx.fillStyle = this.shade(isRoot ? palette.accent : selected ? palette.soft : palette.surface, sideFactor);
      ctx.beginPath();
      ctx.roundRect(x + lift * 0.55, y + lift, item.width, item.height, radius);
      ctx.fill();
    }
    ctx.fillStyle = isRoot ? palette.accent : selected ? palette.soft : palette.surface;
    if (isRoot) {
      ctx.strokeStyle = selected ? palette.onAccent : palette.accent;
      ctx.lineWidth = (selected ? 2.5 : 1) * scale;
    } else if (selected) {
      ctx.strokeStyle = palette.accent;
      ctx.lineWidth = 2.5 * scale;
    } else if (onBranch) {
      ctx.strokeStyle = palette.accent;
      ctx.lineWidth = 1.8 * scale;
    } else if (node.depth === 1) {
      ctx.strokeStyle = palette.accent;
      ctx.lineWidth = 1.2 * scale;
    } else {
      ctx.strokeStyle = palette.border;
      ctx.lineWidth = 1 * scale;
    }
    ctx.beginPath();
    ctx.roundRect(x, y, item.width, item.height, radius);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = isRoot ? palette.onAccent : palette.text;
    ctx.font = `${isRoot ? 'bold ' : ''}${Math.max(7, Math.round(15 * scale))}vp sans-serif`;
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';
    const lineHeight: number = Math.max(10, 22 * scale);
    const firstLine: number = item.y - (node.lines.length - 1) * lineHeight / 2;
    node.lines.forEach((line: string, index: number) => {
      ctx.fillText(line, item.x, firstLine + index * lineHeight, Math.max(1, item.width - 16 * scale));
    });
    if (node.childCount > 0) {
      const badgeRadius: number = 11 * scale;
      ctx.fillStyle = palette.accent;
      ctx.beginPath();
      ctx.arc(x + item.width, item.y, badgeRadius, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = palette.onAccent;
      ctx.font = `${Math.max(6, Math.round((node.collapsed ? 10 : 14) * scale))}vp sans-serif`;
      const badge: string = node.collapsed ? (node.hiddenCount > 99 ? '+99' : '+' + (node.hiddenCount || 0)) : '−';
      ctx.fillText(badge, x + item.width, item.y);
    }
    ctx.textAlign = 'left';
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
      grid: this.color($r('app.color.fs_grid'), dark ? '#2B2D36' : '#DEDFE7'),
      dark: dark
    };
    return this.palette;
  }

  private selectAt(x: number, y: number): void {
    const mapX: number = (x - this.panX) / this.zoom;
    const mapY: number = (y - this.panY) / this.zoom;
    if (this.viewMode === '3d') {
      const projection: Projection = this.projection();
      const items: ProjectedNode[] = this.scene.nodes.map((node: CanvasNode) => this.projectNode(node, projection))
        .sort((a: ProjectedNode, b: ProjectedNode) => a.z - b.z);
      for (const item of items) {
        const left: number = item.x - item.width / 2;
        const top: number = item.y - item.height / 2;
        const padding: number = 8 * item.scale;
        if (mapX >= left - padding && mapX <= left + item.width + 12 * item.scale &&
          mapY >= top - padding && mapY <= top + item.height + padding) {
          this.onSelect(item.node.id);
          const dx: number = mapX - (left + item.width);
          const dy: number = mapY - item.y;
          const radius: number = 12 * item.scale;
          if (item.node.childCount > 0 && dx * dx + dy * dy <= radius * radius) { this.onToggle(item.node.id); }
          return;
        }
      }
      return;
    }
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
