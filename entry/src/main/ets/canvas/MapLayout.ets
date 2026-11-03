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

// Stateless adapter: domain data is never mutated; positions belong only to the view.
export function layoutMap(doc: MindMapDocument): MapScene {
  const children: Map<string, MindMapNode[]> = new Map<string, MindMapNode[]>();
  doc.nodes.forEach((node: MindMapNode) => {
    let list: MindMapNode[] | undefined = children.get(node.parentId);
    if (!list) { list = []; children.set(node.parentId, list); }
    list.push(node);
  });
  children.forEach((list: MindMapNode[]) => list.sort((a: MindMapNode, b: MindMapNode) => a.order - b.order));
  const root: MindMapNode | undefined = doc.nodes.find((node: MindMapNode) => node.id === doc.rootId);
  const scene: MapScene = { nodes: [], width: 240, height: 120 };
  if (!root) { return scene; }
  const spans: Map<string, number> = new Map<string, number>();
  const down: boolean = doc.layout === 'down';
  measureBranch(root, children, spans, down, 0);
  placeBranch(root, children, spans, scene, down, 36, 36, 0);
  return scene;
}

function measureBranch(node: MindMapNode, children: Map<string, MindMapNode[]>, spans: Map<string, number>,
  down: boolean, depth: number): number {
  const size: number = down ? 180 : Math.max(56, nodeLines(node.text).length * 22 + 28);
  const list: MindMapNode[] = node.collapsed || depth >= 8 ? [] : children.get(node.id) || [];
  let total: number = 0;
  list.forEach((child: MindMapNode) => { total += measureBranch(child, children, spans, down, depth + 1) + 24; });
  const span: number = Math.max(size, total > 0 ? total - 24 : 0);
  spans.set(node.id, span);
  return span;
}

function placeBranch(node: MindMapNode, children: Map<string, MindMapNode[]>, spans: Map<string, number>,
  scene: MapScene, down: boolean, axis: number, cross: number, depth: number): void {
  const lines: string[] = nodeLines(node.text);
  const height: number = Math.max(56, lines.length * 22 + 28);
  const span: number = spans.get(node.id) || 180;
  const allChildren: MindMapNode[] = children.get(node.id) || [];
  const box: CanvasNode = { id: node.id, parentId: node.parentId,
    x: down ? cross + (span - 180) / 2 : axis, y: down ? axis : cross + (span - height) / 2,
    width: 180, height: height, lines: lines, collapsed: node.collapsed, childCount: allChildren.length, depth: depth };
  scene.nodes.push(box);
  scene.width = Math.max(scene.width, box.x + box.width + 36);
  scene.height = Math.max(scene.height, box.y + box.height + 36);
  if (node.collapsed || depth >= 8) { return; }
  let cursor: number = cross;
  allChildren.forEach((child: MindMapNode) => {
    placeBranch(child, children, spans, scene, down, axis + (down ? height + 72 : 252), cursor, depth + 1);
    cursor += (spans.get(child.id) || 180) + 24;
  });
}
