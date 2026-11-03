import { MindMapDocument, ChatMessage, GenerationRequest, cloneDocument, newId } from './MindMap';

// Keep the full conversation locally; send a bounded recent context to the gateway.
export function buildGenerationRequest(doc: MindMapDocument, instruction: string,
  create: boolean, selectedNodeId: string): GenerationRequest {
  const snapshot: MindMapDocument = cloneDocument(doc);
  const recent: ChatMessage[] = [];
  let budget: number = 24000;
  for (let index: number = snapshot.messages.length - 1; index >= 0 && recent.length < 20; index--) {
    const message: ChatMessage = snapshot.messages[index];
    if (message.content.length > budget) break;
    recent.unshift(message);
    budget -= message.content.length;
  }
  snapshot.messages = recent;
  return { requestId: newId('request'), documentId: snapshot.documentId, baseRevision: snapshot.revision,
    mode: create ? 'create' : 'revise', instruction: instruction,
    scopeNodeId: create ? '' : selectedNodeId || snapshot.rootId, document: snapshot, messages: recent };
}
