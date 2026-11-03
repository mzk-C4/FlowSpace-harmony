import common from '@ohos.app.ability.common';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import image from '@ohos.multimedia.image';
import drawing from '@ohos.graphics.drawing';
import { MindMapDocument, MindMapNode, cloneDocument, newId } from '../domain/MindMap';
import { validateDocument } from '../domain/DocumentSession';

interface BackupEnvelope {
  format: string;
  version: number;
  document: MindMapDocument;
}

interface ExportBox {
  node: MindMapNode;
  x: number;
  y: number;
  width: number;
  height: number;
  lines: string[];
}

interface ExportLayout {
  boxes: ExportBox[];
  width: number;
  height: number;
}

function children(doc: MindMapDocument, id: string): MindMapNode[] {
  return doc.nodes.filter((node: MindMapNode) => node.parentId === id)
    .sort((a: MindMapNode, b: MindMapNode) => a.order - b.order || a.id.localeCompare(b.id));
}

function lines(text: string, count: number = 15): string[] {
  const result: string[] = [];
  let line: string = '';
  let width: number = 0;
  for (const char of text) {
    if (char === '\n') { result.push(line); line = ''; width = 0; continue; }
    const unit: number = char.charCodeAt(0) > 255 ? 1 : 0.58;
    if (width + unit > count && line.length > 0) { result.push(line); line = ''; width = 0; }
    line += char;
    width += unit;
  }
  if (line.length > 0 || result.length === 0) result.push(line);
  return result;
}

// Export computes every node independently of viewport, zoom and collapsed state.
function fullLayout(doc: MindMapDocument): ExportLayout {
  const boxes: Map<string, ExportBox> = new Map<string, ExportBox>();
  const spans: Map<string, number> = new Map<string, number>();
  const levels: number[] = [];
  const down: boolean = doc.layout === 'down';
  const measure = (node: MindMapNode, depth: number): number => {
    const wrapped: string[] = lines(node.text);
    const box: ExportBox = { node: node, x: 0, y: 0, width: 260, height: Math.max(72, wrapped.length * 22 + 28), lines: wrapped };
    boxes.set(node.id, box);
    levels[depth] = Math.max(levels[depth] || 0, down ? box.height : box.width);
    const list: MindMapNode[] = children(doc, node.id);
    let sum: number = 0;
    for (const child of list) sum += measure(child, depth + 1) + 24;
    if (list.length > 0) sum -= 24;
    const span: number = Math.max(down ? box.width : box.height, sum);
    spans.set(node.id, span);
    return span;
  };
  const root: MindMapNode = doc.nodes.find((node: MindMapNode) => node.id === doc.rootId) as MindMapNode;
  measure(root, 0);
  const offsets: number[] = [];
  let primary: number = 0;
  for (const level of levels) { offsets.push(primary); primary += level + 80; }
  const ordered: ExportBox[] = [];
  const position = (node: MindMapNode, depth: number, start: number): void => {
    const box: ExportBox = boxes.get(node.id) as ExportBox;
    const span: number = spans.get(node.id) as number;
    box.x = 40 + (down ? start + (span - box.width) / 2 : offsets[depth]);
    box.y = 100 + (down ? offsets[depth] : start + (span - box.height) / 2);
    ordered.push(box);
    const list: MindMapNode[] = children(doc, node.id);
    let sum: number = 0;
    for (const child of list) sum += (spans.get(child.id) as number) + 24;
    if (list.length > 0) sum -= 24;
    let cursor: number = start + (span - sum) / 2;
    for (const child of list) { position(child, depth + 1, cursor); cursor += (spans.get(child.id) as number) + 24; }
  };
  position(root, 0, 0);
  let width: number = Math.max(320, doc.title.length * 24 + 80);
  let height: number = 200;
  for (const box of ordered) { width = Math.max(width, box.x + box.width + 40); height = Math.max(height, box.y + box.height + 40); }
  return { boxes: ordered, width: width, height: height };
}

function escapeMarkdown(text: string): string {
  return text.replace(/\\/g, '\\\\').replace(/([`*_{}\[\]<>#])/g, '\\$1').replace(/\r?\n/g, ' ');
}

function backupBytes(text: string): number {
  let size: number = 0;
  for (const char of text) {
    const code: number = char.codePointAt(0) as number;
    size += code < 128 ? 1 : code < 2048 ? 2 : code < 65536 ? 3 : 4;
  }
  return size;
}

class ExportService {
  markdown(doc: MindMapDocument): string {
    validateDocument(doc);
    const output: string[] = ['# ' + escapeMarkdown(doc.title), ''];
    const visit = (node: MindMapNode, depth: number): void => {
      const indent: string = '  '.repeat(depth);
      output.push(indent + '- ' + escapeMarkdown(node.text));
      if (node.note.trim() !== '') output.push(indent + '  > ' + escapeMarkdown(node.note));
      for (const child of children(doc, node.id)) visit(child, depth + 1);
    };
    const root: MindMapNode = doc.nodes.find((node: MindMapNode) => node.id === doc.rootId) as MindMapNode;
    visit(root, 0);
    if (doc.sourceText.trim() !== '') output.push('', '## 原始输入', '', doc.sourceText);
    return output.join('\n') + '\n';
  }

  serialize(doc: MindMapDocument): string {
    validateDocument(doc);
    const envelope: BackupEnvelope = { format: 'flowspace-mindmap', version: 1, document: cloneDocument(doc) };
    const text: string = JSON.stringify(envelope, null, 2);
    if (backupBytes(text) > 8 * 1024 * 1024) throw new Error('导图备份超过 8MB，请缩减超长对话或备注后重试');
    return text;
  }

  parseBackup(text: string): MindMapDocument {
    if (typeof text !== 'string' || text.length > 8 * 1024 * 1024 || backupBytes(text) > 8 * 1024 * 1024) throw new Error('备份超过 8MB 或格式无效');
    const envelope: BackupEnvelope = JSON.parse(text.replace(/^\uFEFF/, '')) as BackupEnvelope;
    if (!envelope || envelope.format !== 'flowspace-mindmap' || envelope.version !== 1) throw new Error('请选择 FlowSpace 思维导图 JSON 备份');
    validateDocument(envelope.document);
    const imported: MindMapDocument = cloneDocument(envelope.document);
    const now: string = new Date().toISOString();
    imported.documentId = newId('map');
    imported.revision = 0;
    imported.createdAt = now;
    imported.updatedAt = now;
    validateDocument(imported);
    return imported;
  }

  private async write(uri: string, data: ArrayBuffer): Promise<void> {
    const file: fs.File = await fs.open(uri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      let offset: number = 0;
      while (offset < data.byteLength) {
        const written: number = await fs.write(file.fd, data.slice(offset));
        if (written <= 0) throw new Error('文件写入失败');
        offset += written;
      }
    } finally { await fs.close(file); }
  }

  async exportDocument(context: common.UIAbilityContext, doc: MindMapDocument, format: string): Promise<void> {
    validateDocument(doc);
    if (format !== 'json' && format !== 'markdown' && format !== 'png') throw new Error('不支持的导出格式');
    const extension: string = format === 'markdown' ? 'md' : format;
    const filename: string = doc.title.replace(/[\\/:*?"<>|\u0000-\u001f]/g, '_').slice(0, 70) || '思维导图';
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
    options.newFileNames = [filename + '.' + extension];
    options.fileSuffixChoices = [extension.toUpperCase() + '|.' + extension];
    const uris: string[] = await new picker.DocumentViewPicker(context).save(options);
    if (uris.length === 0) throw new Error('已取消导出');
    if (format === 'png') {
      await this.write(uris[0], await this.png(doc));
    } else {
      const text: string = format === 'json' ? this.serialize(doc) : this.markdown(doc);
      const bytes: Uint8Array = new util.TextEncoder().encodeInto(text);
      await this.write(uris[0], bytes.buffer as ArrayBuffer);
    }
  }

  async importDocument(context: common.UIAbilityContext): Promise<MindMapDocument> {
    const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    options.fileSuffixFilters = ['JSON|.json'];
    options.maxSelectNumber = 1;
    const uris: string[] = await new picker.DocumentViewPicker(context).select(options);
    if (uris.length === 0) throw new Error('已取消导入');
    const file: fs.File = await fs.open(uris[0], fs.OpenMode.READ_ONLY);
    try {
      const stat: fs.Stat = await fs.stat(file.fd);
      if (stat.size <= 0 || stat.size > 8 * 1024 * 1024) throw new Error('请选择 8MB 以内的 JSON 备份');
      const buffer: ArrayBuffer = new ArrayBuffer(stat.size);
      let offset: number = 0;
      while (offset < stat.size) {
        const part: ArrayBuffer = new ArrayBuffer(stat.size - offset);
        const count: number = await fs.read(file.fd, part);
        if (count <= 0) throw new Error('备份未完整读取');
        new Uint8Array(buffer).set(new Uint8Array(part, 0, count), offset);
        offset += count;
      }
      return this.parseBackup(util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(new Uint8Array(buffer)));
    } finally { await fs.close(file); }
  }

  private async png(doc: MindMapDocument): Promise<ArrayBuffer> {
    const layout: ExportLayout = fullLayout(doc);
    const scale: number = Math.min(1, 4096 / Math.max(layout.width, layout.height));
    const width: number = Math.max(1, Math.min(4096, Math.ceil(layout.width * scale)));
    const height: number = Math.max(1, Math.min(4096, Math.ceil(layout.height * scale)));
    const options: image.InitializationOptions = { size: { width: width, height: height }, pixelFormat: image.PixelMapFormat.RGBA_8888, editable: true };
    const pixels: image.PixelMap = await image.createPixelMap(new ArrayBuffer(width * height * 4), options);
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      const canvas: drawing.Canvas = new drawing.Canvas(pixels);
      canvas.clear(0xFFFAF9F6);
      canvas.scale(scale, scale);
      const brush: drawing.Brush = new drawing.Brush();
      brush.setAntiAlias(true);
      const pen: drawing.Pen = new drawing.Pen();
      pen.setAntiAlias(true);
      pen.setStrokeWidth(2);
      pen.setColor(0xFFABA8CF);
      canvas.attachPen(pen);
      const byId: Map<string, ExportBox> = new Map<string, ExportBox>();
      for (const box of layout.boxes) byId.set(box.node.id, box);
      for (const box of layout.boxes) {
        const parent: ExportBox | undefined = byId.get(box.node.parentId);
        if (parent === undefined) continue;
        if (doc.layout === 'down') canvas.drawLine(parent.x + parent.width / 2, parent.y + parent.height, box.x + box.width / 2, box.y);
        else canvas.drawLine(parent.x + parent.width, parent.y + parent.height / 2, box.x, box.y + box.height / 2);
      }
      canvas.detachPen();
      canvas.attachBrush(brush);
      const font: drawing.Font = new drawing.Font();
      font.setSize(24);
      brush.setColor(0xFF25242B);
      canvas.drawTextBlob(drawing.TextBlob.makeFromString(doc.title, font), 40, 50);
      font.setSize(18);
      for (const box of layout.boxes) {
        brush.setColor(box.node.id === doc.rootId ? 0xFF6558D3 : 0xFFFFFFFF);
        canvas.drawRect(box.x, box.y, box.x + box.width, box.y + box.height);
        brush.setColor(box.node.id === doc.rootId ? 0xFFFFFFFF : 0xFF25242B);
        let y: number = box.y + 30;
        for (const line of box.lines) { canvas.drawTextBlob(drawing.TextBlob.makeFromString(line, font), box.x + 14, y); y += 22; }
      }
      canvas.detachBrush();
      const packing: image.PackingOption = { format: 'image/png', quality: 100 };
      return await packer.packing(pixels, packing);
    } finally { await packer.release(); await pixels.release(); }
  }
}

export const exportService: ExportService = new ExportService();
