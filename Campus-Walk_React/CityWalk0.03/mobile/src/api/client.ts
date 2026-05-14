import AsyncStorage from '@react-native-async-storage/async-storage';
import { API_BASE_URL } from '../config';
import type {
  APIEnvelope,
  ChatMessageDTO,
  CommunityPostDTO,
  CreateConversationDTO,
  LoginResponseDTO,
  NavigationSessionDTO,
  RouteBatchDTO,
  SendMessageResponseDTO,
  UserDTO,
} from './types';

const TOKEN_KEY = 'campus_walk_token';

function asRecord(x: unknown): Record<string, unknown> {
  return x && typeof x === 'object' ? (x as Record<string, unknown>) : {};
}

function pickStr(o: Record<string, unknown>, a: string, b: string): string {
  const v = o[a] ?? o[b];
  return v == null ? '' : String(v);
}

function pickNum(o: Record<string, unknown>, a: string, b: string): number {
  const v = o[a] ?? o[b];
  if (typeof v === 'number' && !Number.isNaN(v)) return v;
  if (typeof v === 'string') {
    const n = Number(v);
    if (!Number.isNaN(n)) return n;
  }
  return 0;
}

function mapUser(o: unknown): UserDTO {
  const r = asRecord(o);
  return {
    id: pickNum(r, 'id', 'id'),
    email: pickStr(r, 'email', 'email'),
    nickname: pickStr(r, 'nickname', 'nickname'),
  };
}

export async function getToken(): Promise<string | null> {
  return AsyncStorage.getItem(TOKEN_KEY);
}

export async function setToken(token: string | null): Promise<void> {
  if (token == null) await AsyncStorage.removeItem(TOKEN_KEY);
  else await AsyncStorage.setItem(TOKEN_KEY, token);
}

function unwrap<T>(raw: unknown): T {
  const env = raw as APIEnvelope<T>;
  if (!env?.success || env.data == null) {
    throw new Error((env?.message ?? env?.result_code ?? '请求失败') as string);
  }
  return env.data;
}

async function parseJson(res: Response): Promise<unknown> {
  const txt = await res.text();
  try {
    return JSON.parse(txt);
  } catch {
    throw new Error(txt.slice(0, 400) || '响应不是合法 JSON');
  }
}

async function authHeaders(): Promise<HeadersInit> {
  const t = await getToken();
  const h: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (t) h.Authorization = `Bearer ${t}`;
  return h;
}

export async function login(email: string, password: string): Promise<LoginResponseDTO> {
  const res = await fetch(`${API_BASE_URL}/api/v1/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const raw = await parseJson(res);
  if (!res.ok) throw new Error((raw as { message?: string }).message ?? `HTTP ${res.status}`);
  const data = unwrap<Record<string, unknown>>(raw);
  const access_token = pickStr(data, 'access_token', 'accessToken');
  const token_type = pickStr(data, 'token_type', 'tokenType') || 'bearer';
  const user = mapUser(data.user);
  return { access_token, token_type, user };
}

export async function me(): Promise<UserDTO> {
  const res = await fetch(`${API_BASE_URL}/api/v1/auth/me`, {
    method: 'GET',
    headers: await authHeaders(),
  });
  const raw = await parseJson(res);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = unwrap<Record<string, unknown>>(raw);
  return mapUser(data);
}

export async function createConversation(title = '新对话'): Promise<CreateConversationDTO> {
  const res = await fetch(`${API_BASE_URL}/api/v1/conversations`, {
    method: 'POST',
    headers: await authHeaders(),
    body: JSON.stringify({ title }),
  });
  const raw = await parseJson(res);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return unwrap<CreateConversationDTO>(raw);
}

export async function listMessages(conversationId: number): Promise<ChatMessageDTO[]> {
  const res = await fetch(`${API_BASE_URL}/api/v1/conversations/${conversationId}/messages`, {
    method: 'GET',
    headers: await authHeaders(),
  });
  const raw = await parseJson(res);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return unwrap<ChatMessageDTO[]>(raw);
}

export async function communityPosts(): Promise<CommunityPostDTO[]> {
  const res = await fetch(`${API_BASE_URL}/api/v1/community/posts`, {
    method: 'GET',
    headers: await authHeaders(),
  });
  const raw = await parseJson(res);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return unwrap<CommunityPostDTO[]>(raw);
}

export async function createNavigationSession(routeVariantId: number): Promise<NavigationSessionDTO> {
  const res = await fetch(`${API_BASE_URL}/api/v1/navigation/sessions`, {
    method: 'POST',
    headers: await authHeaders(),
    body: JSON.stringify({ route_variant_id: routeVariantId }),
  });
  const raw = await parseJson(res);
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return unwrap<NavigationSessionDTO>(raw);
}

function parseJsonLoose<T>(text: string): T {
  return JSON.parse(text) as T;
}

export interface StreamHandlers {
  onUserMessage?: (m: ChatMessageDTO) => void;
  onRouteBatch?: (b: RouteBatchDTO) => void;
  onTextDelta?: (t: string) => void;
}

/**
 * 与 iOS `APIClient.sendMessageStream` 一致：SSE `event:` + 多行 `data:` 拼成 JSON 再解码。
 */
export async function sendMessageStream(
  conversationId: number,
  content: string,
  handlers: StreamHandlers
): Promise<SendMessageResponseDTO> {
  const res = await fetch(`${API_BASE_URL}/api/v1/conversations/${conversationId}/messages/stream`, {
    method: 'POST',
    headers: await authHeaders(),
    body: JSON.stringify({ content, image_base64: null, image_mime_type: null }),
  });
  if (!res.ok) {
    const t = await res.text();
    throw new Error(t.slice(0, 400) || `HTTP ${res.status}`);
  }
  const body = res.body;
  if (!body) throw new Error('无响应体');

  const reader = body.getReader();
  const dec = new TextDecoder();
  let buf = '';
  let currentEvent = '';
  let dataLines: string[] = [];
  let doneResult: SendMessageResponseDTO | undefined;

  const flush = () => {
    if (dataLines.length === 0) return;
    const payload = dataLines.join('\n');
    dataLines = [];
    const name = currentEvent.trim();
    currentEvent = '';
    const nameTrim = name;
    let parsed: unknown;
    try {
      parsed = parseJsonLoose<unknown>(payload);
    } catch {
      return;
    }
    switch (nameTrim) {
      case 'user':
        handlers.onUserMessage?.(parsed as ChatMessageDTO);
        break;
      case 'route_batch':
        handlers.onRouteBatch?.(parsed as RouteBatchDTO);
        break;
      case 'delta': {
        const o = parsed as { text?: string | null; delta?: string | null; content?: string | null };
        const t = o.text ?? o.delta ?? o.content ?? (typeof parsed === 'string' ? parsed : '');
        if (t) handlers.onTextDelta?.(t);
        break;
      }
      case 'done':
        doneResult = parsed as SendMessageResponseDTO;
        break;
      case 'error': {
        const e = parsed as { message?: string | null };
        throw new Error(e.message ?? '流式请求失败');
      }
      default:
        break;
    }
  };

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buf += dec.decode(value, { stream: true });
    const parts = buf.split('\n');
    buf = parts.pop() ?? '';
    for (const line of parts) {
      const trimmed = line.trimEnd();
      if (trimmed === '') {
        flush();
        continue;
      }
      if (trimmed.startsWith('event:')) {
        currentEvent = trimmed.slice(6).trim();
      } else if (trimmed.startsWith('data:')) {
        dataLines.push(trimmed.slice(5).trim());
      }
    }
  }
  buf += dec.decode();
  if (buf.trim().length) {
    for (const line of buf.split('\n')) {
      const trimmed = line.trimEnd();
      if (trimmed === '') flush();
      else if (trimmed.startsWith('event:')) currentEvent = trimmed.slice(6).trim();
      else if (trimmed.startsWith('data:')) dataLines.push(trimmed.slice(5).trim());
    }
  }
  flush();

  if (!doneResult) throw new Error('流式响应未收到 done 事件');
  return doneResult;
}
