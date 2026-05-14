import type { ChatMessageDTO, UiMessage } from '../api/types';

export function chatDtoToUi(m: ChatMessageDTO): UiMessage {
  const raw = m.sent_at ?? '';
  const ts = Date.parse(raw);
  return {
    id: String(m.id),
    content: m.content ?? '',
    isUser: m.role === 'user',
    timestamp: Number.isFinite(ts) ? ts : Date.now(),
    messageType: m.message_type ?? undefined,
    routeVariants: m.route_batch?.variants ?? undefined,
  };
}
