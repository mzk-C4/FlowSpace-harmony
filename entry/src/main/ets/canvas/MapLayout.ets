import { MindMapDocument, MindMapNode } from '../domain/MindMap';

export interface CanvasNode {
  id: string;
  parentId: string;
  x: number;
  y: number;
  width: number;
  height: number;
  lines: string[];
  collapsed: boolean;
  childCount: number;
  hiddenCount: number;
  depth: number;
  side: string;
}

export interface MapScene {
  nodes: CanvasNode[];
  width: number;
  height: number;
}

export function nodeLines(text: string): string[] {
  const lines: string[] = [];
  // Chinese glyphs use one unit, narrow Latin characters approximately half a unit.
  let line: string = '';
  let units: number = 0;
  for (const char of text) {
    const weight: number = (char.codePointAt(0) as number) > 255 ? 1 : 0.56;
    if (char === '\n' || units + weight > 10) {
      lines.push(line);
      line = '';
      units = 0;
    }
    if (char !== '\n') { line += char; units += weight; }
  }
  if (line.length > 0 || lines.length === 0) { lines.push(line); }
  return lines;
}

interface BoxSize {
  width: number;
  height: number;
  lines: string[];
}

interface CenterInfo {
  span: number;
  childTotal: number;
  children: MindMapNode[];
}

function nodeSize(text: string): BoxSize {
  const lines: string[] = nodeLines(text);
  let widest: number = 0;
  for (const line of lines) {
    let units: number = 0;
    for (const char of line) { units += (char.codePointAt(0) as number) > 255 ? 1 : 0.56; }
    widest = Math.max(widest, units);
  }
  return { width: Math.max(76, Math.ceil(widest * 15) + 30), height: Math.max(50, lines.length * 22 + 28), lines: lines };
}

// The domain tree owns the order. All positions and label measurements belong to the view.
export function layoutMap(doc: MindMapDocument, mode: string = doc.layout): MapScene {
  const children: Map<string, MindMapNode[]> = new Map<string, MindMapNode[]>();
  const sizes: Map<string, BoxSize> = new Map<string, BoxSize>();
  doc.nodes.forEach((node: MindMapNode) => {
    let list: MindMapNode[] | undefined = children.get(node.parentId);
    if (!list) { list = []; children.set(node.parentId, list); }
    list.push(node);
    sizes.set(node.id, nodeSize(node.text));
  });
  children.forEach((list: MindMapNode[]) => list.sort((a: MindMapNode, b: MindMapNode) => a.order - b.order));
  const root: MindMapNode | undefined = doc.nodes.find((node: MindMapNode) => node.id === doc.rootId);
  if (!root) { return { nodes: [], width: 120, height: 80 }; }
  const hidden: Map<string, number> = countDescendants(children);
  if (mode === 'center') { return layoutCentered(root, children, sizes, hidden); }
  const scene: MapScene = { nodes: [], width: 0, height: 0 };
  const spans: Map<string, number> = new Map<string, number>();
  const down: boolean = mode === 'down';
  measureBranch(root, children, sizes, spans, down, 0);
  placeBranch(root, children, sizes, spans, hidden, scene, down, 16, 16, 0);
  return scene;
}

// 3D uses a symmetric two-sided layout so the root stays at the orbit center.
function layoutCentered(root: MindMapNode, children: Map<string, MindMapNode[]>,
  sizes: Map<string, BoxSize>, hidden: Map<string, number>): MapScene {
  const scene: MapScene = { nodes: [], width: 0, height: 0 };
  const info: Map<string, CenterInfo> = new Map<string, CenterInfo>();
  const measure = (node: MindMapNode, depth: number): number => {
    const size: BoxSize = sizes.get(node.id) as BoxSize;
    const kids: MindMapNode[] = node.collapsed || depth >= 8 ? [] : children.get(node.id) || [];
    let total: number = 0;
    kids.forEach((child: MindMapNode) => { total += measure(child, depth + 1) + 16; });
    const childTotal: number = kids.length > 0 ? total - 16 : 0;
    const span: number = Math.max(size.height, childTotal);
    info.set(node.id, { span: span, childTotal: childTotal, children: kids });
    return span;
  };
  const makeBox = (node: MindMapNode, depth: number, cx: number, cy: number, side: string): void => {
    const size: BoxSize = sizes.get(node.id) as BoxSize;
    const all: MindMapNode[] = children.get(node.id) || [];
    scene.nodes.push({ id: node.id, parentId: node.parentId,
      x: cx - size.width / 2, y: cy - size.height / 2, width: size.width, height: size.height,
      lines: size.lines, collapsed: node.collapsed, childCount: all.length,
      hiddenCount: node.collapsed ? (hidden.get(node.id) || 0) : 0, depth: depth, side: side });
  };
  const place = (node: MindMapNode, depth: number, cx: number, cy: number, side: string): void => {
    const item: CenterInfo = info.get(node.id) as CenterInfo;
    makeBox(node, depth, cx, cy, side);
    if (item.children.length === 0) { return; }
    const size: BoxSize = sizes.get(node.id) as BoxSize;
    let cursor: number = cy - item.childTotal / 2;
    item.children.forEach((child: MindMapNode) => {
      const childInfo: CenterInfo = info.get(child.id) as CenterInfo;
      const childSize: BoxSize = sizes.get(child.id) as BoxSize;
      const childCy: number = cursor + childInfo.span / 2;
      const childCx: number = side === 'right' ? cx + size.width / 2 + 30 + childSize.width / 2
        : cx - size.width / 2 - 30 - childSize.width / 2;
      place(child, depth + 1, childCx, childCy, side);
      cursor += childInfo.span + 16;
    });
  };
  const rootSize: BoxSize = sizes.get(root.id) as BoxSize;
  const list: MindMapNode[] = children.get(root.id) || [];
  const right: MindMapNode[] = [];
  const left: MindMapNode[] = [];
  list.forEach((child: MindMapNode, index: number) => { (index % 2 === 0 ? right : left).push(child); });
  list.forEach((child: MindMapNode) => { measure(child, 1); });
  const sideSpan = (items: MindMapNode[]): number => {
    let total: number = 0;
    items.forEach((child: MindMapNode) => { total += (info.get(child.id) as CenterInfo).span; });
    return total + Math.max(0, items.length - 1) * 16;
  };
  const rightSpan: number = sideSpan(right);
  const leftSpan: number = sideSpan(left);
  makeBox(root, 0, 0, 0, '');
  let cursor: number = -rightSpan / 2;
  right.forEach((child: MindMapNode) => {
    const childInfo: CenterInfo = info.get(child.id) as CenterInfo;
    const childSize: BoxSize = sizes.get(child.id) as BoxSize;
    place(child, 1, rootSize.width / 2 + 30 + childSize.width / 2, cursor + childInfo.span / 2, 'right');
    cursor += childInfo.span + 16;
  });
  cursor = -leftSpan / 2;
  left.forEach((child: MindMapNode) => {
    const childInfo: CenterInfo = info.get(child.id) as CenterInfo;
    const childSize: BoxSize = sizes.get(child.id) as BoxSize;
    place(child, 1, -rootSize.width / 2 - 30 - childSize.width / 2, cursor + childInfo.span / 2, 'left');
    cursor += childInfo.span + 16;
  });
  let minX: number = Infinity;
  let minY: number = Infinity;
  let maxX: number = -Infinity;
  let maxY: number = -Infinity;
  scene.nodes.forEach((box: CanvasNode) => {
    minX = Math.min(minX, box.x);
    minY = Math.min(minY, box.y);
    maxX = Math.max(maxX, box.x + box.width);
    maxY = Math.max(maxY, box.y + box.height);
  });
  const halfWidth: number = Math.max(-minX, maxX) + 16;
  const halfHeight: number = Math.max(-minY, maxY) + 16;
  scene.nodes.forEach((box: CanvasNode) => { box.x += halfWidth; box.y += halfHeight; });
  scene.width = halfWidth * 2;
  scene.height = halfHeight * 2;
  return scene;
}

// Collapsed branches advertise how much content sits behind the disclosure badge.
function countDescendants(children: Map<string, MindMapNode[]>): Map<string, number> {
  const counts: Map<string, number> = new Map<string, number>();
  const count = (id: string): number => {
    const cached: number | undefined = counts.get(id);
    if (cached !== undefined) { return cached; }
    counts.set(id, 0);
    let total: number = 0;
    (children.get(id) || []).forEach((child: MindMapNode) => { total += 1 + count(child.id); });
    counts.set(id, total);
    return total;
  };
  children.forEach((_list: MindMapNode[], id: string) => { count(id); });
  return counts;
}

function measureBranch(node: MindMapNode, children: Map<string, MindMapNode[]>, sizes: Map<string, BoxSize>,
  spans: Map<string, number>, down: boolean, depth: number): number {
  const box: BoxSize = sizes.get(node.id) as BoxSize;
  const list: MindMapNode[] = node.collapsed || depth >= 8 ? [] : children.get(node.id) || [];
  let total: number = 0;
  list.forEach((child: MindMapNode) => { total += measureBranch(child, children, sizes, spans, down, depth + 1) + 16; });
  const span: number = Math.max(down ? box.width : box.height, total - 16);
  spans.set(node.id, span);
  return span;
}

function placeBranch(node: MindMapNode, children: Map<string, MindMapNode[]>, sizes: Map<string, BoxSize>,
  spans: Map<string, number>, hidden: Map<string, number>, scene: MapScene, down: boolean,
  axis: number, cross: number, depth: number): void {
  const size: BoxSize = sizes.get(node.id) as BoxSize;
  const span: number = spans.get(node.id) as number;
  const allChildren: MindMapNode[] = children.get(node.id) || [];
  const box: CanvasNode = { id: node.id, parentId: node.parentId,
    x: down ? cross + (span - size.width) / 2 : axis, y: down ? axis : cross + (span - size.height) / 2,
    width: size.width, height: size.height, lines: size.lines, collapsed: node.collapsed,
    childCount: allChildren.length, hiddenCount: node.collapsed ? (hidden.get(node.id) || 0) : 0,
    depth: depth, side: '' };
  scene.nodes.push(box);
  scene.width = Math.max(scene.width, box.x + box.width + 16);
  scene.height = Math.max(scene.height, box.y + box.height + 16);
  if (node.collapsed || depth >= 8) { return; }
  let cursor: number = cross;
  allChildren.forEach((child: MindMapNode) => {
    placeBranch(child, children, sizes, spans, hidden, scene, down,
      axis + (down ? size.height + 40 : size.width + 30), cursor, depth + 1);
    cursor += (spans.get(child.id) as number) + 16;
  });
}
