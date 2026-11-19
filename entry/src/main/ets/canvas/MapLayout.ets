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
  depth: number;
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
export function layoutMap(doc: MindMapDocument): MapScene {
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
  const scene: MapScene = { nodes: [], width: 0, height: 0 };
  const spans: Map<string, number> = new Map<string, number>();
  const down: boolean = doc.layout === 'down';
  measureBranch(root, children, sizes, spans, down, 0);
  placeBranch(root, children, sizes, spans, scene, down, 16, 16, 0);
  return scene;
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
  spans: Map<string, number>, scene: MapScene, down: boolean, axis: number, cross: number, depth: number): void {
  const size: BoxSize = sizes.get(node.id) as BoxSize;
  const span: number = spans.get(node.id) as number;
  const allChildren: MindMapNode[] = children.get(node.id) || [];
  const box: CanvasNode = { id: node.id, parentId: node.parentId,
    x: down ? cross + (span - size.width) / 2 : axis, y: down ? axis : cross + (span - size.height) / 2,
    width: size.width, height: size.height, lines: size.lines, collapsed: node.collapsed,
    childCount: allChildren.length, depth: depth };
  scene.nodes.push(box);
  scene.width = Math.max(scene.width, box.x + box.width + 16);
  scene.height = Math.max(scene.height, box.y + box.height + 16);
  if (node.collapsed || depth >= 8) { return; }
  let cursor: number = cross;
  allChildren.forEach((child: MindMapNode) => {
    placeBranch(child, children, sizes, spans, scene, down, axis + (down ? size.height + 40 : size.width + 30), cursor, depth + 1);
    cursor += (spans.get(child.id) as number) + 16;
  });
}
