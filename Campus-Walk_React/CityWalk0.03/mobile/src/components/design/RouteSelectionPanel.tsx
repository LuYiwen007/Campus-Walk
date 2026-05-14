import { Ionicons } from '@expo/vector-icons';
import React from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import type { RouteVariantDTO } from '../../api/types';

export type RouteSelectionPanelProps = {
  originLabel: string;
  destinationLabel: string;
  routes: RouteVariantDTO[];
  selectedId: number;
  onSelect: (id: number) => void;
  onStartWalk: () => void;
  onBack: () => void;
  /** 对齐原型里的「28元起」价格卡片 */
  showPriceCard?: boolean;
};

function formatEta(sec: number): string {
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  if (h <= 0) return `${m}分`;
  return m > 0 ? `${h}小时${m}分` : `${h}小时`;
}

function formatDist(meters: number): string {
  if (meters >= 1000) return `${(meters / 1000).toFixed(1)}公里`;
  return `${Math.round(meters)}米`;
}

/**
 * 对齐 `用户直接搜索选择ui/src/app/App.tsx`：起点终点条 + 底部圆角选路卡 +「开始步行导航」
 */
export function RouteSelectionPanel({
  originLabel,
  destinationLabel,
  routes,
  selectedId,
  onSelect,
  onStartWalk,
  onBack,
  showPriceCard = true,
}: RouteSelectionPanelProps) {
  return (
    <View style={styles.sheet}>
      <View style={styles.topCard}>
        <View style={styles.topRow}>
          <Pressable hitSlop={8} onPress={onBack} style={styles.backBtn}>
            <Ionicons name="arrow-back" size={22} color="#111" />
          </Pressable>
          <View style={{ flex: 1 }}>
            <View style={styles.odRow}>
              <View style={[styles.dot, { backgroundColor: '#22C55E' }]} />
              <Text style={styles.odText}>{originLabel}</Text>
            </View>
            <View style={[styles.odRow, styles.odRowBorder]}>
              <View style={[styles.dot, { backgroundColor: '#EF4444' }]} />
              <Text style={styles.odText}>{destinationLabel}</Text>
            </View>
          </View>
        </View>
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.hScroll}>
        {routes.map((r) => {
          const sel = r.id === selectedId;
          const descShort = r.description?.trim() ? r.description.trim().slice(0, 14) : undefined;
          return (
            <Pressable
              key={r.id}
              onPress={() => onSelect(r.id)}
              style={[styles.routeChip, sel ? styles.routeChipOn : styles.routeChipOff]}
            >
              <Text style={[styles.chipTitle, sel && styles.chipTitleOn]}>{formatEta(r.estimated_duration_seconds)}</Text>
              <Text style={styles.chipSub}>
                {formatDist(r.estimated_distance_meters)}
                {descShort ? ` · ${descShort}` : ''}
              </Text>
              <Text style={styles.chipBadge} numberOfLines={1}>
                {r.display_label}
                {r.scenic_spot_count > 0 ? ` · 途经${r.scenic_spot_count}处` : ''}
              </Text>
            </Pressable>
          );
        })}
        {showPriceCard ? (
          <View style={[styles.routeChip, styles.routeChipOff, { minWidth: 140 }]}>
            <Text style={[styles.chipTitle, { color: '#EF4444' }]}>28元起</Text>
            <Text style={styles.chipSub}>已优惠1元</Text>
            <Text style={[styles.chipBadge, { color: '#6B7280' }]}>特价打车</Text>
          </View>
        ) : null}
      </ScrollView>

      <Pressable style={styles.startBtn} onPress={onStartWalk}>
        <Ionicons name="person" size={18} color="#fff" />
        <Text style={styles.startText}>开始步行导航</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  sheet: {
    backgroundColor: '#fff',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 12,
    shadowColor: '#000',
    shadowOpacity: 0.12,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: -4 },
    elevation: 16,
  },
  topCard: {
    backgroundColor: '#fff',
    paddingHorizontal: 4,
    paddingBottom: 8,
    marginBottom: 8,
  },
  topRow: { flexDirection: 'row', alignItems: 'center' },
  backBtn: { width: 32, height: 32, marginRight: 12, alignItems: 'center', justifyContent: 'center' },
  odRow: { flexDirection: 'row', alignItems: 'center', gap: 8, paddingVertical: 10 },
  odRowBorder: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: '#E5E7EB' },
  dot: { width: 8, height: 8, borderRadius: 4 },
  odText: { fontSize: 16, color: '#111827' },
  hScroll: {
    flexDirection: 'row',
    paddingBottom: 8,
    paddingTop: 4,
    flexGrow: 0,
  },
  routeChip: {
    minWidth: 140,
    marginRight: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 12,
    borderWidth: 2,
  },
  routeChipOn: { borderColor: '#2563EB', backgroundColor: '#EFF6FF' },
  routeChipOff: { borderColor: '#E5E7EB', backgroundColor: '#fff' },
  chipTitle: { fontSize: 22, fontWeight: '700', marginBottom: 4, color: '#111827' },
  chipTitleOn: { color: '#2563EB' },
  chipSub: { fontSize: 12, color: '#4B5563', marginBottom: 2 },
  chipBadge: { fontSize: 12, color: '#2563EB' },
  startBtn: {
    marginTop: 8,
    backgroundColor: '#2563EB',
    borderRadius: 12,
    paddingVertical: 14,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  startText: { color: '#fff', fontSize: 16, fontWeight: '500' },
});
