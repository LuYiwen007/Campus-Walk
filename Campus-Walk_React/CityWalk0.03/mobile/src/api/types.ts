export interface APIEnvelope<T> {
  success: boolean;
  message?: string | null;
  result_code?: string | null;
  data?: T | null;
}

export interface UserDTO {
  id: number;
  email: string;
  nickname: string;
}

export interface LoginResponseDTO {
  access_token: string;
  token_type: string;
  user: UserDTO;
}

export interface ConversationSummaryDTO {
  id: number;
  title: string;
  created_at: string;
}

export interface CreateConversationDTO {
  conversation: ConversationSummaryDTO;
  welcome_message: ChatMessageDTO;
}

export interface RouteVariantDTO {
  id: number;
  route_number: number;
  display_label: string;
  start_label: string;
  end_label: string;
  scenic_spot_count: number;
  scenic_spot_examples: string[];
  estimated_duration_seconds: number;
  estimated_distance_meters: number;
  description: string;
  waypoints?: NavigationWaypointDTO[] | null;
}

export interface NavigationWaypointDTO {
  order: number;
  label: string;
  latitude?: number | null;
  longitude?: number | null;
}

export interface RouteBatchDTO {
  id: number;
  conversation_id: number;
  created_at: string;
  variants: RouteVariantDTO[];
}

export interface ChatMessageDTO {
  id: number;
  conversation_id: number;
  role: string;
  message_type?: string | null;
  content: string;
  sent_at?: string | null;
  route_batch?: RouteBatchDTO | null;
  has_image?: boolean | null;
}

export interface SendMessageResponseDTO {
  user_message?: ChatMessageDTO | null;
  assistant_message: ChatMessageDTO;
  route_batch?: RouteBatchDTO | null;
}

export interface CommunityPostDTO {
  id: number;
  title: string;
  body: string;
  cover_image_url: string;
  author_display_name: string;
  author_avatar_url: string;
  likes_count: number;
  created_at: string;
}

export interface NavigationSessionDTO {
  id: number;
  route_variant_id: number;
  active_leg_index: number;
  status: string;
  waypoints: NavigationWaypointDTO[];
}

export type ChatRole = 'user' | 'assistant' | string;

export interface UiMessage {
  id: string;
  content: string;
  isUser: boolean;
  timestamp: number;
  messageType?: string;
  routeVariants?: RouteVariantDTO[];
}
