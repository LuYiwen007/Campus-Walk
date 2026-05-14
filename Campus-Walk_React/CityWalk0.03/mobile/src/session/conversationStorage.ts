import AsyncStorage from '@react-native-async-storage/async-storage';

/** 与 iOS 侧「同一会话」思路一致：持久化当前旅程 Tab 使用的 conversationId */
export const JOURNEY_CONVERSATION_ID_KEY = 'campus_walk_journey_conversation_id';

export async function loadStoredConversationId(): Promise<number | null> {
  const raw = await AsyncStorage.getItem(JOURNEY_CONVERSATION_ID_KEY);
  if (raw == null || raw.trim() === '') return null;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : null;
}

export async function saveConversationId(id: number): Promise<void> {
  await AsyncStorage.setItem(JOURNEY_CONVERSATION_ID_KEY, String(Math.floor(id)));
}

export async function clearStoredConversationId(): Promise<void> {
  await AsyncStorage.removeItem(JOURNEY_CONVERSATION_ID_KEY);
}
