import common from '@ohos.app.ability.common';
import relationalStore from '@ohos.data.relationalStore';
import preferences from '@ohos.data.preferences';
import { MindMapDocument, DocumentSummary, AppSettings, defaultSettings, cloneDocument } from '../domain/MindMap';
import { validateDocument } from '../domain/DocumentSession';

class DocumentRepository {
  private store: relationalStore.RdbStore | null = null;
  private prefs: preferences.Preferences | null = null;
  private pending: Promise<void> = Promise.resolve();
  private initializing: Promise<void> | null = null;

  async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this.store !== null && this.prefs !== null) return;
    if (this.initializing !== null) return this.initializing;
    this.initializing = this.open(context);
    try { await this.initializing; } finally { this.initializing = null; }
  }

  private async open(context: common.UIAbilityContext): Promise<void> {
    const config: relationalStore.StoreConfig = { name: 'mindmaps.db', securityLevel: relationalStore.SecurityLevel.S1 };
    const store: relationalStore.RdbStore = await relationalStore.getRdbStore(context, config);
    if (store.version > 1) throw new Error('数据库版本较新，请更新应用');
    await store.executeSql('CREATE TABLE IF NOT EXISTS documents (id TEXT PRIMARY KEY, title TEXT NOT NULL, revision INTEGER NOT NULL, node_count INTEGER NOT NULL, updated_at TEXT NOT NULL, payload TEXT NOT NULL)');
    await store.executeSql('CREATE TABLE IF NOT EXISTS recovery (id TEXT PRIMARY KEY, payload TEXT NOT NULL)');
    store.version = 1;
    const prefs: preferences.Preferences = await preferences.getPreferences(context, 'mindmap_settings');
    this.store = store;
    this.prefs = prefs;
  }

  private database(): relationalStore.RdbStore {
    if (this.store === null) throw new Error('存储尚未初始化');
    return this.store;
  }

  private settingsStore(): preferences.Preferences {
    if (this.prefs === null) throw new Error('偏好存储尚未初始化');
    return this.prefs;
  }

  private enqueue(action: () => Promise<void>): Promise<void> {
    const result: Promise<void> = this.pending.then(action);
    this.pending = result.catch((): void => {});
    return result;
  }

  async list(query: string = ''): Promise<DocumentSummary[]> {
    await this.pending;
    const results: relationalStore.ResultSet = await this.database().querySql(
      'SELECT id, title, node_count, updated_at FROM documents WHERE title LIKE ? ORDER BY updated_at DESC', ['%' + query + '%']);
    const list: DocumentSummary[] = [];
    try {
      while (results.goToNextRow()) {
        const item: DocumentSummary = { documentId: results.getString(0), title: results.getString(1), nodeCount: results.getLong(2), updatedAt: results.getString(3) };
        list.push(item);
      }
    } finally { results.close(); }
    return list;
  }

  async get(id: string): Promise<MindMapDocument | null> {
    await this.pending;
    const results: relationalStore.ResultSet = await this.database().querySql('SELECT payload FROM documents WHERE id = ?', [id]);
    let text: string = '';
    let found: boolean = false;
    try {
      found = results.goToFirstRow();
      if (found) text = results.getString(0);
    } finally { results.close(); }
    if (!found) return null;
    try {
      const doc: MindMapDocument = JSON.parse(text) as MindMapDocument;
      validateDocument(doc);
      if (doc.documentId !== id) throw new Error('文档身份不匹配');
      return doc;
    } catch {
      const recovery: relationalStore.ResultSet = await this.database().querySql('SELECT payload FROM recovery WHERE id = ?', [id]);
      try {
        if (!recovery.goToFirstRow()) throw new Error('导图损坏且没有恢复快照');
        const doc: MindMapDocument = JSON.parse(recovery.getString(0)) as MindMapDocument;
        validateDocument(doc);
        if (doc.documentId !== id) throw new Error('恢复快照身份不匹配');
        return doc;
      } finally { recovery.close(); }
    }
  }

  async save(doc: MindMapDocument): Promise<void> {
    validateDocument(doc);
    const snapshot: MindMapDocument = cloneDocument(doc);
    await this.enqueue(async (): Promise<void> => {
      const db: relationalStore.RdbStore = this.database();
      const existing: relationalStore.ResultSet = await db.querySql('SELECT revision, payload FROM documents WHERE id = ?', [snapshot.documentId]);
      let validPrevious: boolean = false;
      try {
        if (existing.goToFirstRow()) {
          if (existing.getLong(0) > snapshot.revision) throw new Error('拒绝覆盖较新的导图版本');
          try {
            const previous: MindMapDocument = JSON.parse(existing.getString(1)) as MindMapDocument;
            validateDocument(previous);
            validPrevious = previous.documentId === snapshot.documentId;
          } catch { validPrevious = false; }
        }
      } finally { existing.close(); }
      const payload: string = JSON.stringify(snapshot);
      db.beginTransaction();
      try {
        if (validPrevious) await db.executeSql('INSERT OR REPLACE INTO recovery (id, payload) SELECT id, payload FROM documents WHERE id = ?', [snapshot.documentId]);
        await db.executeSql('INSERT OR REPLACE INTO documents (id, title, revision, node_count, updated_at, payload) VALUES (?, ?, ?, ?, ?, ?)',
          [snapshot.documentId, snapshot.title, snapshot.revision, snapshot.nodes.length, snapshot.updatedAt, payload]);
        await db.executeSql('INSERT OR IGNORE INTO recovery (id, payload) VALUES (?, ?)', [snapshot.documentId, payload]);
        db.commit();
      } catch (error) { db.rollBack(); throw new Error((error as Error).message); }
    });
  }

  async delete(id: string): Promise<void> {
    await this.enqueue(async (): Promise<void> => {
      const db: relationalStore.RdbStore = this.database();
      db.beginTransaction();
      try {
        await db.executeSql('DELETE FROM recovery WHERE id = ?', [id]);
        await db.executeSql('DELETE FROM documents WHERE id = ?', [id]);
        db.commit();
      } catch (error) { db.rollBack(); throw new Error((error as Error).message); }
    });
  }

  async loadSettings(): Promise<AppSettings> {
    await this.pending;
    const text: string = await this.settingsStore().get('settings', '') as string;
    if (text === '') return defaultSettings();
    const settings: AppSettings = JSON.parse(text) as AppSettings;
    this.validateSettings(settings);
    return settings;
  }

  private validateSettings(settings: AppSettings): void {
    if (!settings || typeof settings.backendUrl !== 'string' || !/^https?:\/\/[^\s]+$/.test(settings.backendUrl)) throw new Error('后端地址无效');
    if (settings.themeMode !== 'system' && settings.themeMode !== 'light' && settings.themeMode !== 'dark') throw new Error('外观设置无效');
    if (typeof settings.reduceMotion !== 'boolean') throw new Error('动效设置无效');
  }

  async saveSettings(settings: AppSettings): Promise<void> {
    this.validateSettings(settings);
    const text: string = JSON.stringify(settings);
    await this.enqueue(async (): Promise<void> => {
      await this.settingsStore().put('settings', text);
      await this.settingsStore().flush();
    });
  }
}

export const documentRepository: DocumentRepository = new DocumentRepository();
