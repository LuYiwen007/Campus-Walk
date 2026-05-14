import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  Alert,
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { AppMapView } from '../maps/AppMapView';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NavigationHud } from '../components/design/NavigationHud';
import { RouteSelectionPanel } from '../components/design/RouteSelectionPanel';
import * as Api from '../api/client';
import type { ChatMessageDTO, RouteVariantDTO, UiMessage } from '../api/types';
import { chatDtoToUi } from '../chat/mapMessage';
import {
  clearStoredConversationId,
  loadStoredConversationId,
  saveConversationId,
} from '../session/conversationStorage';
import { Theme } from '../theme';

const initialRegion = {
  latitude: 39.9042,
  longitude: 116.4074,
  latitudeDelta: 0.05,
  longitudeDelta: 0.05,
};

/** 无历史路线时用于「回到地图」演示（字段满足 RouteVariantDTO） */
const DEMO_ROUTE_VARIANTS: RouteVariantDTO[] = [
  {
    id: 901,
    route_number: 1,
    display_label: '推荐方案',
    start_label: '我的位置',
    end_label: '十渡孤山寨 → 三渡',
    scenic_spot_count: 2,
    scenic_spot_examples: [],
    estimated_duration_seconds: 6 * 3600 + 6 * 60,
    estimated_distance_meters: 24500,
    description: '254 路况',
  },
  {
    id: 902,
    route_number: 2,
    display_label: '打车',
    start_label: '我的位置',
    end_label: '十渡孤山寨 → 三渡',
    scenic_spot_count: 0,
    scenic_spot_examples: [],
    estimated_duration_seconds: 3600 + 47 * 60,
    estimated_distance_meters: 24500,
    description: '254 路况',
  },
  {
    id: 903,
    route_number: 3,
    display_label: '骑行',
    start_label: '我的位置',
    end_label: '十渡孤山寨 → 三渡',
    scenic_spot_count: 0,
    scenic_spot_examples: [],
    estimated_duration_seconds: 5 * 3600 + 6 * 60,
    estimated_distance_meters: 24500,
    description: '254 路况',
  },
];

function lastRouteVariantsFromMessages(msgs: UiMessage[]): RouteVariantDTO[] | null {
  for (let i = msgs.length - 1; i >= 0; i--) {
    const v = msgs[i]?.routeVariants;
    if (v && v.length > 0) return v;
  }
  return null;
}

function formatEtaLine(sec: number): string {
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  if (h <= 0) return `${m}分`;
  return m > 0 ? `${h}小时${m}分` : `${h}小时`;
}

function formatDistLine(meters: number): string {
  if (meters >= 1000) return `${(meters / 1000).toFixed(1)}公里`;
  return `${Math.round(meters)}米`;
}

function arrivalClockLabel(secondsFromNow: number): string {
  const t = new Date(Date.now() + secondsFromNow * 1000);
  const h = t.getHours();
  const mi = t.getMinutes();
  return `${String(h).padStart(2, '0')}:${String(mi).padStart(2, '0')}到达`;
}

export function JourneyScreen() {
  const [conversationId, setConversationId] = useState<number | null>(null);
  const [messages, setMessages] = useState<UiMessage[]>([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [bootErr, setBootErr] = useState<string | null>(null);
  const [showMap, setShowMap] = useState(false);
  const [mapPhase, setMapPhase] = useState<'routes' | 'nav'>('routes');
  const [routePickList, setRoutePickList] = useState<RouteVariantDTO[]>([]);
  const [routePickSelectedId, setRoutePickSelectedId] = useState<number>(0);
  const listRef = useRef<FlatList<UiMessage>>(null);

  const bootstrap = useCallback(async () => {
    setBootErr(null);
    try {
      const storedId = await loadStoredConversationId();
      if (storedId != null) {
        try {
          const list = await Api.listMessages(storedId);
          setConversationId(storedId);
          setMessages(list.map(chatDtoToUi));
          return;
        } catch {
          await clearStoredConversationId();
        }
      }
      const created = await Api.createConversation('新对话');
      await saveConversationId(created.conversation.id);
      setConversationId(created.conversation.id);
      setMessages([chatDtoToUi(created.welcome_message)]);
    } catch (e) {
      setBootErr(e instanceof Error ? e.message : String(e));
    }
  }, []);

  const startNewConversation = useCallback(async () => {
    if (busy) return;
    setBootErr(null);
    setBusy(true);
    try {
      await clearStoredConversationId();
      const created = await Api.createConversation('新对话');
      await saveConversationId(created.conversation.id);
      setConversationId(created.conversation.id);
      setMessages([chatDtoToUi(created.welcome_message)]);
    } catch (e) {
      setBootErr(e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }, [busy]);
  useEffect(() => {
    void bootstrap();
  }, [bootstrap]);

  const append = useCallback((m: UiMessage) => {
    setMessages((prev) => [...prev, m]);
    requestAnimationFrame(() => listRef.current?.scrollToEnd({ animated: true }));
  }, []);

  const onSend = useCallback(async () => {
    const text = input.trim();
    if (!text || conversationId == null || busy) return;
    setInput('');
    setBusy(true);
    const tempAsstId = `stream-${Date.now()}`;
    try {
      const res = await Api.sendMessageStream(conversationId, text, {
        onUserMessage: (dto: ChatMessageDTO) => {
          append(chatDtoToUi(dto));
        },
        onRouteBatch: (batch) => {
          append({
            id: tempAsstId,
            content: '',
            isUser: false,
            timestamp: Date.now(),
            messageType: 'route_plan',
            routeVariants: batch.variants,
          });
        },
        onTextDelta: (piece) => {
          setMessages((prev) => {
            const idx = prev.findIndex((x) => x.id === tempAsstId);
            if (idx < 0) return prev;
            const next = [...prev];
            next[idx] = { ...next[idx], content: next[idx].content + piece };
            return next;
          });
        },
      });
      const merged =
        res.route_batch?.variants ?? res.assistant_message.route_batch?.variants ?? undefined;
      const finalMsg = chatDtoToUi(res.assistant_message);
      setMessages((prev) => {
        const idx = prev.findIndex((x) => x.id === tempAsstId);
        if (idx >= 0) {
          const next = [...prev];
          next[idx] = {
            ...finalMsg,
            id: String(finalMsg.id),
            routeVariants: merged ?? finalMsg.routeVariants,
          };
          return next;
        }
        return [...prev, { ...finalMsg, routeVariants: merged ?? finalMsg.routeVariants }];
      });
      if (res.user_message) {
        const u = chatDtoToUi(res.user_message);
        setMessages((prev) => {
          const next = [...prev];
          const uid = String(res.user_message!.id);
          const j = next.findIndex((m) => m.isUser && m.id === uid);
          if (j >= 0) next[j] = u;
          return next;
        });
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      append({
        id: `err-${Date.now()}`,
        content: `发送失败：${msg}`,
        isUser: false,
        timestamp: Date.now(),
      });
    } finally {
      setBusy(false);
    }
  }, [append, busy, conversationId, input]);

  const openMapWithRoutes = useCallback((variants: RouteVariantDTO[] | null | undefined, preferredId?: number) => {
    const list = variants && variants.length > 0 ? variants : DEMO_ROUTE_VARIANTS;
    setRoutePickList(list);
    const pid = preferredId ?? list[0]?.id ?? 0;
    setRoutePickSelectedId(pid);
    setMapPhase('routes');
    setShowMap(true);
  }, []);

  const closeMap = useCallback(() => {
    setShowMap(false);
    setMapPhase('routes');
  }, []);

  const onStartWalkNavigation = useCallback(async () => {
    const v = routePickList.find((r) => r.id === routePickSelectedId);
    if (!v) {
      Alert.alert('导航', '请先选择一条路线');
      return;
    }
    try {
      await Api.createNavigationSession(v.id);
      setMapPhase('nav');
    } catch (e) {
      Alert.alert('导航会话', e instanceof Error ? e.message : String(e));
    }
  }, [routePickList, routePickSelectedId]);

  const selectedVariant = useMemo(
    () => routePickList.find((r) => r.id === routePickSelectedId) ?? routePickList[0],
    [routePickList, routePickSelectedId]
  );
  const header = useMemo(
    () => (
      <View style={styles.chatHeader}>
        <Pressable
          hitSlop={8}
          onPress={() => void startNewConversation()}
          disabled={busy}
          style={({ pressed }) => [{ opacity: busy ? 0.35 : pressed ? 0.7 : 1 }]}
        >
          <Text style={styles.headerLink}>新对话</Text>
        </Pressable>
        <View style={{ alignItems: 'center' }}>
          <Text style={styles.chatTitle}>聊天</Text>
          <Text style={styles.chatSub}>Chat</Text>
        </View>
        <View style={{ width: 56 }} />
      </View>
    ),
    [busy, startNewConversation]
  );

  if (showMap) {
    const originLabel = selectedVariant?.start_label ?? '起点';
    const destLabel = selectedVariant?.end_label ?? '终点';
    const walkSec = selectedVariant?.estimated_duration_seconds ?? 0;
    const walkM = selectedVariant?.estimated_distance_meters ?? 0;

    return (
      <View style={styles.mapRoot}>
        <AppMapView style={StyleSheet.absoluteFill} initialRegion={initialRegion} showsUserLocation />
        {mapPhase === 'routes' ? (
          <View style={styles.mapSheetWrap} pointerEvents="box-none">
            <SafeAreaView edges={['bottom']} style={{ backgroundColor: 'transparent' }}>
              <RouteSelectionPanel
                originLabel={originLabel}
                destinationLabel={destLabel}
                routes={routePickList}
                selectedId={routePickSelectedId}
                onSelect={setRoutePickSelectedId}
                onStartWalk={() => void onStartWalkNavigation()}
                onBack={closeMap}
                showPriceCard
              />
            </SafeAreaView>
          </View>
        ) : null}
        {mapPhase === 'nav' && selectedVariant ? (
          <NavigationHud
            nextMeters={200}
            nextActionText="向右前方行驶"
            totalLine={`${formatDistLine(walkM)} · ${formatEtaLine(walkSec)}`}
            arrivalText={arrivalClockLabel(walkSec)}
            onExit={() => setMapPhase('routes')}
            onVoice={() => {}}
            onRecenter={() => {}}
          />
        ) : null}
        <SafeAreaView style={styles.mapFabSafeTop} edges={['top', 'right']}>
          <Pressable style={styles.mapFab} onPress={closeMap}>
            <Text style={styles.mapFabText}>返回聊天</Text>
          </Pressable>
        </SafeAreaView>
      </View>
    );
  }
  return (
    <KeyboardAvoidingView
      style={{ flex: 1 }}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      keyboardVerticalOffset={80}
    >
      <SafeAreaView style={styles.chatRoot} edges={['top']}>
        {header}
        <View style={styles.divider} />
        {bootErr ? (
          <View style={styles.center}>
            <Text style={styles.muted}>{bootErr}</Text>
          </View>
        ) : (
          <>
            <FlatList
              ref={listRef}
              data={messages}
              keyExtractor={(m) => m.id}
              contentContainerStyle={{ padding: 16, paddingBottom: 96 }}
              style={{ flex: 1, backgroundColor: '#F2F2F7' }}
              onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: true })}
              renderItem={({ item }) => (
                <View style={[styles.row, item.isUser ? styles.rowUser : styles.rowBot]}>
                  {!item.isUser ? (
                    <View style={styles.botIcon}>
                      <Text style={{ fontSize: 18 }}>✦</Text>
                    </View>
                  ) : null}
                  <View style={{ flex: 1, alignItems: item.isUser ? 'flex-end' : 'flex-start' }}>
                    {item.routeVariants && item.routeVariants.length > 0 ? (
                      <View style={{ gap: 8, width: '100%' }}>
                        {item.routeVariants.map((v) => (
                          <Pressable
                            key={v.id}
                            onPress={() => openMapWithRoutes(item.routeVariants, v.id)}
                            style={styles.routeCard}
                          >
                            <Text style={styles.routeTitle}>{v.display_label}</Text>
                            <Text style={styles.routeSub}>
                              {v.start_label} → {v.end_label}
                            </Text>
                            <Text style={styles.routeDesc} numberOfLines={3}>
                              {v.description}
                            </Text>
                          </Pressable>
                        ))}
                      </View>
                    ) : null}
                    {item.content ? (
                      <View style={[styles.bubble, item.isUser ? styles.bubbleUser : styles.bubbleBot]}>
                        <Text style={[styles.bubbleText, item.isUser && { color: '#fff' }]}>{item.content}</Text>
                      </View>
                    ) : null}
                    <Text style={styles.time}>
                      {new Date(item.timestamp).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })}
                    </Text>
                  </View>
                  {item.isUser ? (
                    <View style={styles.userIcon}>
                      <Text style={{ color: '#fff' }}>●</Text>
                    </View>
                  ) : null}
                </View>
              )}
            />
            <Pressable style={styles.backMapBtn} onPress={() => openMapWithRoutes(lastRouteVariantsFromMessages(messages))}>
              <Text style={styles.backMapText}>回到地图</Text>
            </Pressable>
            <View style={styles.inputRow}>
              <TextInput
                style={styles.input}
                value={input}
                onChangeText={setInput}
                placeholder="输入消息…"
                placeholderTextColor={Theme.textMuted}
                editable={!busy && conversationId != null}
                onSubmitEditing={() => void onSend()}
              />
              <Pressable
                style={[styles.sendBtn, (!input.trim() || busy) && { opacity: 0.45 }]}
                disabled={!input.trim() || busy}
                onPress={() => void onSend()}
              >
                <Text style={styles.sendBtnText}>发送</Text>
              </Pressable>
            </View>
          </>
        )}
      </SafeAreaView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  chatRoot: { flex: 1, backgroundColor: '#fff' },
  chatHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingBottom: 10,
    backgroundColor: '#fff',
  },
  headerLink: { fontSize: 15, fontWeight: '600', color: Theme.brandBlue },
  chatTitle: { fontSize: 18, fontWeight: '700', color: '#111' },
  chatSub: { fontSize: 12, fontWeight: '500', color: Theme.textSecondary, marginTop: 2 },
  divider: { height: StyleSheet.hairlineWidth, backgroundColor: '#C6C6C8' },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  muted: { color: Theme.textMuted },
  row: { flexDirection: 'row', alignItems: 'flex-start', gap: 10, marginBottom: 12 },
  rowUser: { justifyContent: 'flex-end' },
  rowBot: { justifyContent: 'flex-start' },
  botIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(147,51,234,0.12)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  userIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: Theme.brandBlue,
    alignItems: 'center',
    justifyContent: 'center',
  },
  bubble: {
    maxWidth: '82%',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 18,
  },
  bubbleUser: {
    backgroundColor: Theme.brandBlue,
    borderTopLeftRadius: 18,
    borderTopRightRadius: 18,
    borderBottomLeftRadius: 18,
    borderBottomRightRadius: 4,
  },
  bubbleBot: {
    backgroundColor: '#fff',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(60,60,67,0.29)',
    borderTopLeftRadius: 4,
    borderTopRightRadius: 18,
    borderBottomLeftRadius: 18,
    borderBottomRightRadius: 18,
  },
  bubbleText: { fontSize: 16, color: '#111' },
  time: { fontSize: 11, color: '#8E8E93', marginTop: 4 },
  routeCard: {
    width: '100%',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: Theme.cardStroke,
    padding: 12,
    backgroundColor: '#fff',
  },
  routeTitle: { fontSize: 15, fontWeight: '600', color: Theme.textPrimary },
  routeSub: { fontSize: 13, color: Theme.textSecondary, marginTop: 4 },
  routeDesc: { fontSize: 13, color: Theme.textMuted, marginTop: 6 },
  backMapBtn: {
    position: 'absolute',
    right: 16,
    bottom: 88,
    backgroundColor: Theme.brandBlue,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 22,
    shadowColor: '#000',
    shadowOpacity: 0.12,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 2 },
    elevation: 3,
  },
  backMapText: { color: '#fff', fontWeight: '600' },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: '#C6C6C8',
    backgroundColor: '#fff',
  },
  input: {
    flex: 1,
    minHeight: 40,
    maxHeight: 120,
    borderRadius: 20,
    paddingHorizontal: 14,
    backgroundColor: '#F2F2F7',
    color: '#111',
  },
  sendBtn: {
    backgroundColor: Theme.brandBlue,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
  },
  sendBtnText: { color: '#fff', fontWeight: '600' },
  mapRoot: { flex: 1, backgroundColor: '#000' },
  mapFabSafeTop: { position: 'absolute', top: 0, right: 0 },
  mapFab: {
    margin: 16,
    backgroundColor: '#fff',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: Theme.cardStroke,
  },
  mapSheetWrap: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
  },
  mapFabText: { color: Theme.brandBlue, fontWeight: '600' },
});
